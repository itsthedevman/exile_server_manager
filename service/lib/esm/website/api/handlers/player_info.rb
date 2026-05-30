# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Fetches a player's Exile account/character data for the website.
        #
        # The steam_uid is supplied by the caller (the website derives it from the
        # session, never from user input). The Arma round-trip blocks, so the work is
        # offloaded to a Concurrent::Promise and the bot replies once it resolves
        # (see Server#respond_when_resolved), keeping the NATS dispatch thread free.
        #
        # @return [Concurrent::Promise] resolving to the player's data hash, or nil
        #   when the player has no character on the server.
        #
        class PlayerInfo
          def self.call(server_id:, steam_uid:)
            info!(event: "player_info", server_id:, steam_uid:)

            server = ESM::Server.find(server_id)
            raise ArgumentError, "Unknown server: #{server_id}" if server.nil?

            Concurrent::Promise.execute do
              server.query_exile_database!("player_info", uid: steam_uid).first
            end
          end
        end
      end
    end
  end
end
