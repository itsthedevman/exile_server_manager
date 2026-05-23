# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Accepts a pending request, triggering whatever follow-up the originating
        # command registered. No-op when the request has already been resolved.
        #
        class RequestsAccept
          def self.call(id:, **)
            info!(event: "requests:accept", id: id)

            request = ESM::Request.where(id: id).first
            return if request.nil?

            request.respond(true)
          end
        end
      end
    end
  end
end
