# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerSuccessCommandV1 < ApplicationCommand
        command_type :player
        requires :registration

        argument :server_id
        argument :nullable, regex: /.*/, default: nil

        def on_execute
          deliver!
          self
        end

        def on_response(_, _)
          reply("Yaay")
        end
      end
    end
  end
end
