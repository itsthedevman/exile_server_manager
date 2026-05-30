# frozen_string_literal: true

module Servers
  class PlayersController < AuthenticatedController
    def me
      render locals: {
        server: current_server,
        player: current_player
      }
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end

    def current_player
      ESM.cache.fetch("player_#{current_server.id}_#{current_user.steam_uid}", expires_in: 10.seconds) do
        current_server.player_info(current_user.steam_uid)
      end
    end
  end
end
