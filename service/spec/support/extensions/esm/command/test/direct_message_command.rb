# frozen_string_literal: true

module ESM
  module Command
    module Test
      class DirectMessageCommand < ApplicationCommand
        command_type :player
        limit_to :dm

        def on_execute
        end

        def on_response
        end
      end
    end
  end
end
