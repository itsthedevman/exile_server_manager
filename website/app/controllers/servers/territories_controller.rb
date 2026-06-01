# frozen_string_literal: true

module Servers
  class TerritoriesController < AuthenticatedController
    def show
      render locals: {
        current_server:,
        current_territory:
      }
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end

    def current_territory
      # The result is scoped to this player's territory rights, so the cache key must
      # include their steam_uid. A shared key would let an owner's cached payload be
      # served to a user who has no access to the territory.
      territory_data =
        ESM.cache.fetch(
          "territory_#{current_server.id}_#{params[:territory_id]}_#{current_user.steam_uid}", expires_in: 5.seconds
        ) do
          current_server.territory_info(params[:territory_id], steam_uid: current_user.steam_uid)
        end

      return if territory_data.blank?

      ESM::Exile::Territory.new(server: current_server, territory: territory_data)
    end
  end
end
