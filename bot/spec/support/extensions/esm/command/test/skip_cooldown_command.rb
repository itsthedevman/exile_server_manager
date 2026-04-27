# frozen_string_literal: true

module ESM
  module Command
    module Test
      class SkipCooldownCommand < ApplicationCommand
        command_type :player

        def on_execute
          skip_action(:cooldown)
        end

        def on_response
        end
      end
    end
  end
end
