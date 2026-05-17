# frozen_string_literal: true

module ESM
  module Command
    module Test
      class CooldownCommand < ApplicationCommand
        change_attribute :cooldown_time, default: 10.seconds

        def on_execute
        end

        def on_response
        end
      end
    end
  end
end
