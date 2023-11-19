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
          send_to_arma(type: :echo, data: {type: :empty})
          self
        end

        def on_response(_, _)
          reply("Yaay")
        end
      end
    end
  end
end
