# frozen_string_literal: true

module Servers
  class TerritoriesController < RegisteredController
    include TerritoryLoading
    include PlayerLoading

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
      command = ESM::ServerCommand.find_by(public_id: params[:command_id], user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {
        command:,
        current_server: command.server,
        refreshed_territory: refreshed_territory(command),
        refreshed_player: refreshed_player(command),
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
      @current_server ||= ESM::Server.includes(:community).find_by_public_id(params[:server_id])
    end

    def current_territory
      load_territory(current_server, params[:territory_id], current_user.steam_uid)
    end

    def run_territory_command(command_name, arguments: {})
      # The client mints idempotency_key per form render, so a double-click
      # dedupes to the same row and the payment fires once.
      command = ESM::ServerCommand.find_or_create_by(
        user_id: current_user.id,
        idempotency_key: params.require(:idempotency_key)
      ) do |new_command|
        new_command.server = current_server
        new_command.command_name = command_name

        new_command.arguments = {
          server_id: current_server.server_id,
          community_id: current_server.community.community_id,
          territory_id: params.require(:territory_territory_id)
        }.merge(arguments)
      end

      # A non-pending row means this one was already dispatched (a re-click on a
      # stale button); skip re-firing and just render its current state.
      if command.pending?
        ESM::Service::API.call(:server_command, command_id: command.id)

        # Give a quick payment a moment to land so it resolves in this response
        # rather than flashing a spinner the client poller clears a beat later.
        Poll.until(timeout: 1.second, every: 0.1.seconds) { command.reload.settled? }
      end

      render partial: "command_response", locals: {
        command:,
        dom_id: params.require(:dom_id),
        current_server:,
        refreshed_territory: refreshed_territory(command),
        refreshed_player: refreshed_player(command),
        retry_territory: retry_territory(command)
      }
    end
  end
end
