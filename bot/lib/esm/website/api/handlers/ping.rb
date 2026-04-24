# frozen_string_literal: true

module ESM
  module Website
    module API
      module Handlers
        #
        # Echoes the payload back with a server-side
        # timestamp and a nonce so the soak harness can confirm that the
        # response it receives corresponds to the request it sent.
        #
        class Ping
          def call(**payload)
            {
              echo: payload,
              server_time: Time.now.utc.iso8601(6),
              nonce: SecureRandom.uuid
            }
          end
        end
      end
    end
  end
end
