# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Pushes a fresh initialization package to a connected server so it
        # picks up settings changes without a full disconnect.
        #
        class ServersUpdate
          def self.call(id:, **)
            server = ESM::Server.find_by(id:)
            return if server.nil?

            if server.v2?
              connection = server.connection
              return true if connection.nil?

              connection.close(I18n.t("server_disconnect.reasons.settings_update"))
            else
              connection = ESM::Websocket.connection(server.server_id)
              return true if connection.nil?

              ESM::Event::ServerInitializationV1.new(connection: connection, server: server, parameters: {}).update
            end
          end
        end
      end
    end
  end
end
