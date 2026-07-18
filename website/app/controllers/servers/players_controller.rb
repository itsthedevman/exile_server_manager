# frozen_string_literal: true

module Servers
  class PlayersController < RegisteredController
    include PlayerLoading
    include Commands

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
      command = call_service_command("stuck")

      render turbo_stream: turbo_stream.replace(target, partial: "reset_result", locals: {target:, command:})
    end

    private

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations).find_by_public_id(params[:server_id])
    end

    def current_player
      load_player(current_server, current_user.steam_uid)
    end
  end
end
