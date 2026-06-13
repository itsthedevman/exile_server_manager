# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Fetches a single territory for the website, scoped to the requesting player.
        #
        # The Arma round-trip blocks, so the work is offloaded to a Concurrent::Promise
        # and the bot replies once it resolves (see Server#respond_when_resolved),
        # keeping the NATS dispatch thread free.
        #
        # @return [Concurrent::Promise] resolving to the territory data hash, or nil
        #   when the player has no rights to the territory.
        #
        class TerritoryInfo
          def self.call(server_id:, encoded_territory_id:, steam_uid:)
            server = ESM::Server.find_by(id: server_id)
            raise ArgumentError, "Unknown server: #{server_id}" if server.nil?

            # steam_uid scopes the lookup to a territory this player has rights to.
            # The website always supplies it (derived from the session, never user
            # input); an unauthorized territory_id resolves to nil.
            Concurrent::Promise.execute do
              server.query_exile_database!(
                "territory_info",
                territory_id: encoded_territory_id,
                requesting_uid: steam_uid
              ).first
            end
          end
        end
      end
    end
  end
end
