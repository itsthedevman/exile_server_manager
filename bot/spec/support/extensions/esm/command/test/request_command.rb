# frozen_string_literal: true

module ESM
  module Command
    module Test
      class RequestCommand < ApplicationCommand
        command_type :player

        argument :target

        def on_execute
          add_request(to: target_user)
        end

        def on_response(_, _)
        end

        def request_accepted
          ESM.bot.deliver("accepted", to: @request.requestor.discord_user)
        end

        def request_declined
          ESM.bot.deliver("declined", to: @request.requestor.discord_user)
        end
      end
    end
  end
end
