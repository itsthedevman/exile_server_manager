# frozen_string_literal: true

module Servers
  class TerritoriesController < RegisteredController
    include TerritoryLoading
    include PlayerLoading
    include Commands

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
        retry_territory: retry_territory(command)
      }
    end
  end
end
