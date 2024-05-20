# frozen_string_literal: true

module ESM
  module Command
    module Test
      class PlayerCommand < ApplicationCommand
        command_type :player

        def on_execute
          "on_execute"
        end

        def on_response
          "on_response"
        end
      end
    end
  end
end
