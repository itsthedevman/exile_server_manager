# frozen_string_literal: true

module ESM
  module Command
    module Test
      class AdminCommand < ApplicationCommand
        command_type :admin

        argument :community_id

        def on_execute
        end

        def on_response
        end
      end
    end
  end
end
