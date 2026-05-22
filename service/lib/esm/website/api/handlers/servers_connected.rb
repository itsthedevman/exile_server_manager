# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns true when the named server currently has a live connection to the bot.
        #
        class ServersConnected
          def self.call(id:, **)
            info!(event: "servers:connected", id: id)

            server = ESM::Server.find_by(id: id)
            return if server.nil?

            server.connected?
          end
        end
      end
    end
  end
end
