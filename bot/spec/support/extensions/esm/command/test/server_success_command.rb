# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerSuccessCommand < ApplicationCommand
        command_type :player
        requires :registration

        argument :server_id
        argument :nullable, regex: /.*/, default: nil

        def on_execute
          message = ESM::Message.new.set_type(:echo)
          send_to_target_server(message)
        end

        def on_response
          reply("Yaay")
        end
      end
    end
  end
end
