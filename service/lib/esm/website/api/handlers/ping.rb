# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Echoes the request payload back with the bot's wall-clock. Used as a liveness
        # probe across the NATS transport.
        #
        class Ping
          def self.call(**payload)
            {echo: payload, server_time: Time.now.utc.iso8601}
          end
        end
      end
    end
  end
end
