# frozen_string_literal: true

module Servers
  class PlayersController < RegisteredController
    include PlayerLoading
    include Commands
    include ServerVersion

    before_action :require_supported_server!

    # The listing answers "who has been around lately", so the look-back is the axis an admin steers. Anyone holding a
    # uid for a long-inactive player reaches that player directly rather than widening this until they appear.
    LOOKBACK_WINDOWS = {
      "24h" => {label: "24 hours", duration: 24.hours},
      "7d" => {label: "7 days", duration: 7.days},
      "30d" => {label: "30 days", duration: 30.days}
    }.freeze

    DEFAULT_LOOKBACK = "7d"

    # Mirrors the query's own cap. The whole window crosses NATS as a single message, so this is a payload budget
    # rather than a page size, and the page paginates rows it already holds.
    ROW_LIMIT = 250

    # Long enough to collapse a burst - several admins landing at once, a reload, a window flipped and flipped back -
    # and short enough that the page never argues with what the server just did. Nothing here polls on its own, so a
    # burst is the only load the cache has to absorb.
    CACHE_TTL = 5.seconds

    # Identity barely moves - a Steam profile and a Discord account are not going to change while an admin reads the
    # page - so this only has to collapse reloads and the re-renders a player action triggers.
    IDENTITY_CACHE_TTL = 30.seconds

    # Exile's account.name is a varchar(64), so anything past that could never match a row. Capping here keeps a
    # hand-edited query string from turning into an unbounded cache key.
    NAME_SEARCH_LIMIT = 64

    PLAYER_ACTIONS = %w[money locker respect heal kill].freeze
    BALANCE_ACTIONS = %w[money locker respect].freeze

    def index
      return unless check_for_command_access("players")

      render locals: {current_server:, lookback:, search_name:}
    end

    # The listing itself, loaded lazily into a turbo frame so a slow read never holds up the page around it.
    def list
      return unless check_for_command_access("players")

      snapshot = players_snapshot

      render locals: {
        current_server:,
        lookback:,
        lookback_options: LOOKBACK_WINDOWS,
        search_name:,
        players: snapshot&.dig(:players),
        fetched_at: snapshot&.dig(:fetched_at),
        row_limit: ROW_LIMIT
      }
    end

    # The server hub's lookup bar, where an admin arrives holding whichever identifier they happen to have. Everything
    # but a name resolves to a Steam UID, so those hand off to the pages already built to answer for one. What is left
    # is the two ways a Discord ID dead-ends, and those are answers in their own right rather than a failed lookup.
    def lookup
      return unless check_for_command_access("info")

      result = ESM::PlayerLookup.call(params[:q])

      case result.kind
      when :steam_uid
        redirect_to server_player_path(current_server.public_id, result.steam_uid)
      when :name
        redirect_to server_players_path(current_server.public_id, name: result.query)
      when :blank
        redirect_to server_path(current_server.public_id)
      else
        render locals: {current_server:, result:}
      end
    end

    # One player's full on-server snapshot - the admin counterpart to /me, reached from the listing's row button or a
    # direct UID. It runs as the admin against a target UID, so a player who's dropped off the listing's recency window
    # is still reachable by UID alone.
    def show
      return unless check_for_command_access("info")

      # Marks that the on-screen overview belongs to the viewed player.
      # A territory action taken from here then refreshes that player's overview through info rather than the viewer's
      # own me snapshot. See PlayerLoading#refreshed_player.
      session[:viewing_player_uid] = target_uid

      snapshot = target_player_snapshot(target_uid)

      render locals: {
        current_server:,
        target_uid:,
        target_player: player_from(snapshot),
        identity: target_identity,
        fetched_at: snapshot&.dig(:fetched_at)
      }
    end

    def me
      return unless check_for_command_access("me")

      # The overview here is the viewer's own; clearing the marker means a territory action refreshes it from me rather
      # than a stale viewed player.
      session.delete(:viewing_player_uid)

      snapshot = current_player_snapshot

      render locals: {
        current_server:,
        current_player: player_from(snapshot),
        fetched_at: snapshot&.dig(:fetched_at)
      }
    end

    # Compact glance for the My Player card on the server hub. Loaded lazily into
    # a turbo frame so the hub lands instantly and a slow Arma read never blocks it.
    def summary
      render locals: {
        current_server:,
        current_player:
      }
    end

    # Self-service "I'm stuck" character reset. The name-bar button guards it with a confirm (the web stand-in for the
    # Discord self-confirmation request), so the web path skips the request and runs straight through.
    def reset_me
      return unless check_for_command_access("stuck")

      command = call_async_command("stuck")

      ESM.cache.delete(current_player_cache_key) # Drop the cache, the player no longer exists in the database
      render_reset_response(command)
    end

    # Admin character reset for the viewed player. Like reset_me, the confirm dialog is the web stand-in for the Discord
    # self-confirmation, so the web path runs straight through. Keyed off the path uid rather than a loaded character, so
    # it reaches the bugged/unspawnable player reset exists to fix even when info returned nothing to show.
    def reset
      return unless check_for_command_access("reset")

      command = call_async_command("reset", arguments: {target: target_uid})

      ESM.cache.delete(target_player_cache_key(target_uid)) # Drop the cache, the character no longer exists
      render_reset_response(command)
    end

    # Admin "reset all characters" - wipes every character on the server. The index toolbar guards it behind a typed
    # confirmation (the web stand-in for the Discord self-confirmation), so the web path runs straight through with no
    # target, which the reset command resolves to reset_all. The recently-connected listing is account data reset doesn't
    # touch, so there's nothing to bust; the short-lived per-player info caches lapse on their own.
    def reset_all
      return unless check_for_command_access("reset")

      command = call_async_command("reset")

      render_reset_response(command)
    end

    # Admin player actions on the viewed player: heal, kill, or adjust pocket/locker poptabs or respect. The player
    # command's SQF handles online and offline players alike, so nothing gates here beyond command access. A balance
    # action carries a magnitude and a give/remove direction, folded into the signed amount the command expects.
    def modify
      return unless check_for_command_access("player")

      command = call_async_command(
        "player",
        arguments: {target: target_uid, action: player_action, amount: player_amount}
      )

      ESM.cache.delete(target_player_cache_key(target_uid)) # Balances / character state just changed
      render partial: "player_action_response", locals: {
        command:,
        current_server:,
        target_uid:,
        refreshed_player: refreshed_player(command),
        viewing_self: viewing_self?
      }
    end

    # Polled by the service-command Stimulus controller after a reset dispatch, until the command settles. Scoped to the
    # current user so nobody can watch another player's command by id. Renders no streams while the row is still pending,
    # so the poller leaves its spinner up until the command reaches a terminal state.
    def status
      command = ESM::ServiceCommand.find_by(public_id: params[:command_id], user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {
        command:,
        current_server: command.server,
        refreshed_player: refreshed_player(command),
        viewing_self: viewing_self?
      }
    end

    private

    # Renders the shared reset command_response: a settled command fires its outcome toast and, on success, re-renders the
    # overview from the refreshed post-reset player - all we still hold (locker, scoreboard, territories) with the
    # character read as gone - falling back to the no-character empty state only when nothing remains to show. A
    # still-pending command drops a spinner that polls #status until it settles.
    def render_reset_response(command)
      render partial: "command_response", locals: {
        command:,
        dom_id: params.require(:dom_id),
        current_server:,
        refreshed_player: refreshed_player(command),
        viewing_self: viewing_self?
      }
    end

    # The player action to run, constrained to the command's five so a hand-edited form can't smuggle another through.
    # Named player_action, not action: `action` is Rails' reserved routing key (it holds the controller action), so a
    # form field of that name never survives into params.
    def player_action
      action = params.require(:player_action)
      return action if PLAYER_ACTIONS.include?(action)

      raise ActionController::BadRequest, "Unknown player action: #{action}"
    end

    # The signed amount for a balance action - a positive magnitude gives, a negative one removes - or nil for heal and
    # kill, which take no amount. The web splits give/remove into two buttons; the sign is the only difference the command
    # sees, which is a Discord-ism the dashboard shouldn't make an admin type.
    def player_amount
      return unless BALANCE_ACTIONS.include?(params[:player_action])

      magnitude = params[:amount].to_i.abs
      (params[:direction] == "remove") ? -magnitude : magnitude
    end

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations).find_by_public_id(params[:server_id])
    end

    def current_player
      load_player
    end

    # The Steam UID whose character the show page describes. It's an Arma-side lookup key handed to the info command as
    # its target, not the acting caller - the caller stays current_user.
    def target_uid
      params[:uid]
    end

    # Anything unrecognized falls back to the default, so a hand-edited query string can't hand the command a window
    # the page never offered.
    def lookback
      @lookback ||= LOOKBACK_WINDOWS.key?(params[:window]) ? params[:window] : DEFAULT_LOOKBACK
    end

    # The name being searched for, or nil when the page is showing its usual recency listing. Present, it puts the page
    # in name mode: the query drops the window entirely and matches on the name instead, which is the whole point.
    # Someone being looked up by name has usually stopped appearing in the window.
    def search_name
      @search_name ||= params[:name].to_s.strip.slice(0, NAME_SEARCH_LIMIT).presence
    end

    # Keyed on the server and window rather than the viewer, so a page full of admins costs the game server one read
    # instead of one each. The rows are the same for all of them, and access is checked before this ever runs.
    #
    # The read is stamped rather than timed at render, or every cache hit would claim to be current.
    def players_snapshot
      ESM.cache.fetch(players_cache_key, expires_in: CACHE_TTL) do
        connected_since = LOOKBACK_WINDOWS.fetch(lookback)[:duration].ago

        # connected_since rides along in name mode and the query ignores it, so the command keeps one required
        # argument rather than one that is required only sometimes.
        players = call_sync_command(
          "players",
          arguments: {
            connected_since: connected_since.utc.iso8601,
            limit: ROW_LIMIT,
            name: search_name
          }.compact
        )

        {fetched_at: Time.current, players:}
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        # Degrade the way the player snapshot does: an unreachable bot or game server leaves the frame showing an
        # offline state rather than a 500, and the nil caches so a down server isn't retried on every reload.
        Rails.logger.warn("[players#list] player list unavailable: #{e.message}")
        nil
      end
    end

    # Who this UID belongs to: Steam always, Discord only when whois is willing to say. Identity is not character
    # data, so it does not ride on info's verdict - a community can hand info to its moderators while keeping whois
    # to its admins, and gating separately is what lets them.
    #
    # Degrades to nil rather than taking the page down with it. The character overview below is the reason the admin
    # came, and it is still worth showing when the identity lookup can't answer.
    def target_identity
      return unless command_accessible?("whois")

      ESM.cache.fetch(identity_cache_key, expires_in: IDENTITY_CACHE_TTL) do
        call_sync_command("whois", arguments: {target: target_uid})
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        Rails.logger.warn("[players#show] identity unavailable: #{e.message}")
        nil
      end
    end

    # Scoped to the community, not just the UID. Whether Discord comes back at all depends on the caller's community
    # membership check, so one community's answer must never be served to another's admin.
    def identity_cache_key
      "whois_#{current_server.community_id}_#{target_uid}"
    end

    # A name search answers a different question than the recency listing, so it gets its own entry rather than
    # overwriting the listing every admin shares.
    def players_cache_key
      return "players_#{current_server.id}_name_#{search_name.downcase}" if search_name

      "players_#{current_server.id}_#{lookback}"
    end
  end
end
