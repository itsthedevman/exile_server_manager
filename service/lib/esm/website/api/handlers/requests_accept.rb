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
            request = ESM::Request.find_by(id:)
            return if request.nil?

            request.accept!
          end
        end
      end
    end
  end
end
