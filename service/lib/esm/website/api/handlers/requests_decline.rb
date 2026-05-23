# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Declines a pending request, triggering the originating command's decline path.
        #
        class RequestsDecline
          def self.call(id:, **)
            info!(event: "requests:decline", id: id)

            request = ESM::Request.where(id: id).first
            return if request.nil?

            request.respond(false)
          end
        end
      end
    end
  end
end
