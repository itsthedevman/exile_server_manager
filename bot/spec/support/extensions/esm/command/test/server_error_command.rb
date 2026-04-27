# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerErrorCommand < ApplicationCommand
        command_type :player

        argument :server_id

        def on_execute
          message = ESM::Message.new
            .set_type(:echo)
            .add_error(:message, "this is an error message")

          send_to_target_server!(message)
        end

        def on_response
        end
      end
    end
  end
end
