# frozen_string_literal: true

#
# This entire file is dedicated to the migration methods from @esm v1 to @esm v2
# This file will be deleted once the migration has been completed
#
module ESM
  module Command
    class Base
      # V1
      module Migration
        extend ActiveSupport::Concern

        def v1_code_needed?
          defined?(self.class::V1) && !v2_target_server?
        end

        def load_v1_code!
          extend(self.class::V1) # Overwrites V2 logic
        end

        # V1
        # @deprecated Use on_execute instead
        def discord
        end

        # V1
        # @deprecated Use on_response instead
        def server
        end

        #
        # V1: This is called when the message is received from the server
        #
        def from_server(response)
          load_v1_code! if v1_code_needed?

          # Event is always an array. 90% of the time, event size will only be 1
          # This just makes typing a little easier when writing commands
          @response = (response.size == 1) ? response.first : response

          # Trigger the callback
          on_response(nil, nil)
        end

        # V1: Send a request to the DLL
        #
        # @param command_name [String, nil] V1: The name of the command to send to the DLL. Default: self.name.
        def deliver!(command_name: nil, timeout: 30, **parameters)
          raise ESM::Exception::CheckFailure, "Command does not have an associated server" if target_server.nil?

          # Build the request
          request =
            ESM::Websocket::Request.new(
              command: self,
              command_name: command_name,
              user: current_user,
              channel: current_channel,
              parameters: parameters,
              timeout: timeout
            )

          # Send it to the dll
          ESM::Websocket.deliver!(target_server.server_id, request)
        end

        def v2_target_server?
          !!target_server&.v2?
        end
      end
    end
  end
end
