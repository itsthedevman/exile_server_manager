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
      data =
        ESM.cache.fetch("player_#{current_server.id}_#{current_user.steam_uid}", expires_in: 5.seconds) do
          current_server.player_info(current_user.steam_uid)
        end

      # No character on this server yet (never spawned in, or server offline)
      return if data.blank?

      data[:territories]&.map! { |territory| ESM::Exile::Territory.new(server: current_server, territory:) }
        &.sort_by!(&:id)

      data.to_istruct
    end
  end
end
