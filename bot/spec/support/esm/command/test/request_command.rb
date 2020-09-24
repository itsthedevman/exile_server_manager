# frozen_string_literal: true

module ESM
  module Command
    module Test
      class RequestCommand < ESM::Command::Base
        type :player

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :target

        def discord
          add_request(to: target_user)
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
