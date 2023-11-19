# frozen_string_literal: true

module ESM
  module Command
    module Test
      class CommunityAndServerCommand < ApplicationCommand
        command_type :player
        requires :registration

        argument :community_id
        argument :server_id

        def on_execute
        end

        def on_response(_, _)
        end
      end
    end
  end
end
