# frozen_string_literal: true

module Servers
  class PlayersController < AuthenticatedController
    include PlayerLoading

    def me
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
