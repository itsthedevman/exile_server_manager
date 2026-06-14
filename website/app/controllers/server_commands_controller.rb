# frozen_string_literal: true

class ServerCommandsController < AuthenticatedController
  include TerritoryLoading

  # Polled by the pay Stimulus controller until the command settles. Scoped to
  # the current user so nobody can read another player's command by id.
  def show
    command = ESM::ServerCommand.find_by(id: params[:id], user_id: current_user.id)
    return head :not_found if command.nil?

    render locals: {
      command:,
      current_server: command.server,
      refreshed_territory: refreshed_territory(command)
    }
  end
end
