# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Answers that the bot is up and subscribed.
        #
        # Touches nothing, so it is safe to call repeatedly and says only what a caller waiting on a boot needs to
        # know: a reply means the subscription is live, where a NoRespondersError means it is not. Every other handler
        # would answer the same question by doing work, and would fail for reasons of its own.
        #
        class Ping
          def self.call(**payload)
            {echo: payload, server_time: ::Time.current.iso8601}
          end
        end
      end
    end
  end
end
