# frozen_string_literal: true

module Communities
  class CooldownsController < RegisteredController
    include Commands

    # Inactive rows are the overwhelming majority and only exist to answer "was this ever on cooldown", so the
    # archive view is capped rather than paginated. Mirrors the players listing's own cap: a budget, not a page size.
    INACTIVE_LIMIT = 250

    def index
      return unless check_for_command_access("reset_cooldown")

      # The page loads the whole set and narrows it in the browser. Filtering a hundred rows the client already holds
      # does not need a round trip, and making it one meant a control firing an event nobody asked for could start a
      # navigation. Only the inactive toggle reaches back here, because that changes what is loaded rather than what
      # is shown.
      render locals: card_locals
    end

    def clear
      return unless check_for_command_access("reset_cooldown")

      command = call_async_command("reset_cooldown", arguments: scope_arguments)

      # Read after the command has settled, so the card that goes back is the one the clear left behind rather than
      # the one it was asked from.
      render locals: {command:, result: result_for(command)}.merge(card_locals)
    end

    def status
      command = ESM::ServiceCommand.find_by(public_id: params.require(:command_id), user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {command:, result: result_for(command)}.merge(card_locals)
    end

    private

    ##
    # Everything the card needs to draw itself. Shared by the initial render and by the response to a clear, which
    # sends the whole card back rather than redirecting: the layout morphs on a same-URL visit, and a morph would
    # strip the search controls SlimSelect mounts without ever reconnecting their Stimulus controllers.
    #
    def card_locals
      cooldowns = listed_cooldowns.to_a

      {
        cooldowns:,
        players: players_for(cooldowns),
        showing_inactive: showing_inactive?,
        capped: showing_inactive? && cooldowns.size >= INACTIVE_LIMIT,
        row_limit: INACTIVE_LIMIT,
        player_options: player_options(cooldowns),
        command_options: command_options(cooldowns),
        server_options: current_community.servers.sort_by(&:server_id)
      }
    end

    # Every row this community owns, narrowed to the running ones unless the archive was asked for. Inactive rows are
    # never deleted, so the unnarrowed set grows with every command any player has ever run here.
    def listed_cooldowns
      scope = ESM::Cooldown.where(community_id: current_community.id)
      return scope.active.order(expires_at: :asc) unless showing_inactive?

      scope.order(expires_at: :desc).limit(INACTIVE_LIMIT)
    end

    # "Inactive" rather than "expired" throughout, because a usage allowance that is only part spent has not expired.
    # It has a clock that never mattered and a count it has not reached, and it renders as "1 of 2 uses", which under
    # a label promising expired rows reads as a bug.
    def showing_inactive?
      params[:inactive] == "1"
    end

    # The filters a clear was submitted with, nil meaning "any". The selects live inside the clear form, so what the
    # browser was showing is what arrives here, with nothing in between to disagree.
    def current_filters
      {
        player: params[:player].presence,
        command: params[:command].presence,
        server: params[:server].presence
      }
    end

    def player_options(cooldowns)
      cooldowns
        .filter_map { |cooldown| resolved_players[cooldown.id] }
        .uniq(&:id)
        .select { |player| player.steam_uid.present? }
        .sort_by { |player| player.username.to_s.downcase }
    end

    def command_options(cooldowns)
      cooldowns.map(&:command_name).uniq.sort
    end

    # Cooldown#user resolves a row at a time, by whichever key that row carries, which is a query per row on a page
    # whose whole job is to list rows. Both keys are looked up once here instead.
    def players_for(cooldowns)
      by_id = ESM::User.where(id: cooldowns.filter_map(&:user_id).uniq).index_by(&:id)
      by_steam_uid = ESM::User.where(steam_uid: cooldowns.filter_map { |c| c.steam_uid.presence }.uniq)
        .index_by(&:steam_uid)

      @resolved_players =
        cooldowns.to_h { |cooldown| [cooldown.id, by_id[cooldown.user_id] || by_steam_uid[cooldown.steam_uid]] }
    end

    def resolved_players
      @resolved_players || {}
    end

    def server_for(public_id)
      current_community.servers.find { |server| server.public_id == public_id }
    end

    # The filters translated into the command's own arguments. The page and the command describe a scope the same
    # way, so what the table showed is what gets cleared, with nothing in between to disagree.
    def scope_arguments
      filters = current_filters
      arguments = {}

      arguments[:target] = filters[:player] if filters[:player]
      arguments[:command] = filters[:command] if filters[:command]

      if filters[:server]
        server = server_for(filters[:server])
        not_found! if server.nil?

        arguments[:server_id] = server.server_id
      end

      arguments
    end

    # What the result partial renders: how many rows were cleared, the player-facing reason it did not happen, or nil
    # while the command is still in flight.
    def result_for(command)
      return unless command.settled?
      return {error: command.error_message, cleared: nil}.to_datum if command.error_message.present?

      {error: nil, cleared: command.result[:cleared]}.to_datum
    end

    # Overrides Commands#render_command_denied. A denial reports itself the same way an outcome does, since both
    # answer the button that was just pressed and neither should be pinned to a region the response may replace.
    def render_command_denied(message)
      respond_to do |format|
        format.html { not_found! }

        format.turbo_stream do
          render(
            turbo_stream: helpers.create_error_toast(message, title: "Can't clear cooldowns", color: "red"),
            status: :unprocessable_content
          )
        end
      end
    end

    # Overrides Commands#command_denied_message with cooldown-specific wording.
    def command_denied_message(reason)
      case reason
      when :unregistered
        "Link your Steam account on your account page before you can clear cooldowns."
      when :disabled
        "Cooldown resets are not enabled on #{current_community.community_id}."
      when :not_allowlisted
        "You do not have permission to clear cooldowns on #{current_community.community_id}."
      else
        "You can't clear cooldowns right now."
      end
    end
  end
end
