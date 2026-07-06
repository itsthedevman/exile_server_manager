# frozen_string_literal: true

module Servers
  class PlayersController < RegisteredController
    include PlayerLoading

    def me
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

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end

    def current_player
      load_player(current_server, current_user.steam_uid)
    end
  end
end
