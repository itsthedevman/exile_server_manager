# frozen_string_literal: true

module Servers
  class TerritoriesController < RegisteredController
    include TerritoryLoading
    include PlayerLoading
    include Commands

    # Same window the player and territory reads use: long enough to collapse a burst of admins landing at once, short
    # enough that the list never argues with a restore that just happened. Nothing here polls, so a burst is the only
    # load it has to absorb.
    CACHE_TTL = 5.seconds

    # The admin territories listing - every territory on the server, the counterpart to the players list. Loaded lazily
    # into a turbo frame so a slow read never holds up the page around it.
    def index
      return unless check_for_command_access("server_territories")

      render locals: {current_server:}
    end

    def list
      return unless check_for_command_access("server_territories")

      snapshot = territories_snapshot

      render locals: {
        current_server:,
        territories: territories_from(snapshot&.dig(:rows)),
        fetched_at: snapshot&.dig(:fetched_at)
      }
    end

    # Restores a territory Exile has flagged for deletion (clears its deleted_at). Runs straight through like the other
    # admin territory actions; on success the caller reloads the list frame off a busted cache so the row loses its
    # marked-for-deletion state.
    def restore
      return unless check_for_command_access("restore")

      command = call_async_command("restore", arguments: {territory_id: params.require(:territory_territory_id)})

      ESM.cache.delete(territories_cache_key)
      render partial: "restore_response", locals: {command:, current_server:}
    end

    def show
      render locals: {
        current_server:,
        current_territory:
      }
    end

    def pay
      run_territory_command("pay")
    end

    def upgrade
      run_territory_command("upgrade")
    end

    def add_member
      run_territory_command("add", arguments: {target: params.require(:target_uid)})
    end

    def promote_member
      run_territory_command("promote", arguments: {target: params.require(:target_uid)})
    end

    def remove_member
      run_territory_command("remove", arguments: {target: params.require(:target_uid)})
    end

    def demote_member
      run_territory_command("demote", arguments: {target: params.require(:target_uid)})
    end

    # Polled by the pay Stimulus controller after a dispatch, until the command
    # settles. Scoped to the current user so nobody can watch another player's
    # command by id. Renders no streams while the row is still pending, so the
    # poller leaves its spinner up until the command reaches a terminal state.
    def status
      command = ESM::ServiceCommand.find_by(public_id: params[:command_id], user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {
        command:,
        current_server: command.server,
        refreshed_territory: refreshed_territory(command),
        refreshed_player: refreshed_player(command),
        viewing_self: viewing_self?,
        retry_territory: retry_territory(command)
      }
    end

    def set_id
      run_territory_command("set_id", arguments: {
        old_territory_id: params.require(:territory_territory_id),
        new_territory_id: params.require(:custom_id)
      })
    end

    private

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations).find_by_public_id(params[:server_id])
    end

    # Keyed on the server rather than the viewer, so a page full of admins costs the game server one read of the whole
    # territory set instead of one each. The read is stamped rather than timed at render, or every cache hit would claim
    # to be current. Degrades to nil on an unreachable bot/server so the frame shows an offline state, not a 500.
    def territories_snapshot
      ESM.cache.fetch(territories_cache_key, expires_in: CACHE_TTL) do
        {fetched_at: Time.current, rows: call_sync_command("server_territories")}
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        Rails.logger.warn("[territories#list] territory list unavailable: #{e.message}")
        nil
      end
    end

    def territories_cache_key
      "territories_#{current_server.id}"
    end

    # Turns the raw all_territories rows into the same ESM::Exile::Territory the modal and player cards use, so the list's
    # level, object count, stolen, payment-due, and marked-for-deletion all come from one shared source of truth. Nil rows
    # (offline) pass straight through so the view can tell "offline" from "no territories".
    def territories_from(rows)
      return if rows.nil?

      rows.map { |row| ESM::Exile::Territory.new(server: current_server, territory: row) }
    end

    def current_territory
      load_territory(params[:territory_id])
    end

    def run_territory_command(command_name, arguments: {})
      return unless check_for_command_access(command_name)

      command = call_async_command(
        command_name,
        arguments: arguments.merge(territory_id: params.require(:territory_territory_id))
      )

      render partial: "command_response", locals: {
        command:,
        dom_id: params.require(:dom_id),
        current_server:,
        refreshed_territory: refreshed_territory(command),
        refreshed_player: refreshed_player(command),
        viewing_self: viewing_self?,
        retry_territory: retry_territory(command)
      }
    end
  end
end
