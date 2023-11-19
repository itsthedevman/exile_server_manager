# frozen_string_literal: true

module ESM
  module Command
    module Test
      class CommunityCommand < ApplicationCommand
        command_type :player

        argument :community_id

        def on_execute
        end

        def on_response(_, _)
        end
      end
    end
  end
end
