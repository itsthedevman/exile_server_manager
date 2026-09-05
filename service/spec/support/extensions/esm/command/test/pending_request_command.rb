# frozen_string_literal: true

module ESM
  module Command
    module Test
      # RequestCommand without the gate, so the two can be driven independently. check_for_pending_request! is opt-in
      # rather than part of the lifecycle, which means testing it needs a command that actually calls it.
      class PendingRequestCommand < ApplicationCommand
        command_type :player

        argument :target

        def on_execute
          check_for_pending_request!

          add_request(to: target_user)
        end

        def on_response
        end

        def on_request_accepted
          ESM.discord_bot.deliver("accepted", to: @request.requestor.discord_user)
        end

        def on_request_declined
          ESM.discord_bot.deliver("declined", to: @request.requestor.discord_user)
        end
      end
    end
  end
end
