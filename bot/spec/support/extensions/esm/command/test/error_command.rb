# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Test
      class ErrorCommand < ApplicationCommand
        command_type :player

        def on_execute
          raise StandardError, "Oops"
        end

        def on_response(_, _)
        end
      end
    end
  end
end
