# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerCommand < ApplicationCommand
        command_type :player
        requires :registration

        argument :server_id

        def on_execute
        end

        def on_response
        end

        def on_accept
        end

        def on_decline
        end
      end
    end
  end
end
