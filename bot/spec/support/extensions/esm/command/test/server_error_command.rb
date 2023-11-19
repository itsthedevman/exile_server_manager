# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerErrorCommand < ApplicationCommand
        command_type :player

        argument :server_id

        def on_execute
          send_to_arma(
            type: :echo,
            data: {type: :empty},
            errors: [{type: :message, content: "this is an error message"}]
          )
        end

        def on_response(_, _)
        end
      end
    end
  end
end
