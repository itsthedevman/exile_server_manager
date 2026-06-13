# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Disconnects a server using its previous ID after a community renames itself.
        # The Arma DLL reconnects automatically against the new ID within ~30 seconds.
        #
        class ServersReconnect
          def self.call(id:, old_id:, **)
            server = ESM::Server.find_by(id:)
            return if server.nil?
            return if old_id.blank?

            connection = ESM::Websocket.connection(old_id)
            return if connection.nil?

            connection.connection.close(1000, "Server ID changed, reconnecting")
          end
        end
      end
    end
  end
end
