# frozen_string_literal: true

module Servers
  class PlayersController < RegisteredController
    include PlayerLoading
    include Commands

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

    def index
      return unless check_for_command_access("players")

      render locals: {current_server:, lookback:}
    end

    # The listing itself, loaded lazily into a turbo frame so a slow read never holds up the page around it.
    def list
      return unless check_for_command_access("players")

      snapshot = players_snapshot

      render locals: {
        current_server:,
        lookback:,
        lookback_options: LOOKBACK_WINDOWS,
        players: snapshot&.dig(:players),
        fetched_at: snapshot&.dig(:fetched_at),
        row_limit: ROW_LIMIT
      }
    end

    def me
      return unless check_for_command_access("me")

      render locals: {
        current_server:,
        current_player:
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

      target = params.require(:dom_id)
      command = call_async_command("stuck")

      render turbo_stream: turbo_stream.replace(target, partial: "reset_result", locals: {target:, command:})
    end

    private

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations).find_by_public_id(params[:server_id])
    end

    def current_player
      load_player
    end

    # Anything unrecognized falls back to the default, so a hand-edited query string can't hand the command a window
    # the page never offered.
    def lookback
      @lookback ||= LOOKBACK_WINDOWS.key?(params[:window]) ? params[:window] : DEFAULT_LOOKBACK
    end

    # Keyed on the server and window rather than the viewer, so a page full of admins costs the game server one read
    # instead of one each. The rows are the same for all of them, and access is checked before this ever runs.
    #
    # The read is stamped rather than timed at render, or every cache hit would claim to be current.
    def players_snapshot
      ESM.cache.fetch("players_#{current_server.id}_#{lookback}", expires_in: CACHE_TTL) do
        connected_since = LOOKBACK_WINDOWS.fetch(lookback)[:duration].ago

        players = call_sync_command(
          "players",
          arguments: {connected_since: connected_since.utc.iso8601, limit: ROW_LIMIT}
        )

        {fetched_at: Time.current, players:}
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        # Degrade the way the player snapshot does: an unreachable bot or game server leaves the frame showing an
        # offline state rather than a 500, and the nil caches so a down server isn't retried on every reload.
        Rails.logger.warn("[players#list] player list unavailable: #{e.message}")
        nil
      end
    end
  end
end
