# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerCommand < ESM::Command::Base
        set_type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def on_execute
        end

        def on_response(_, _)
        end

        def on_accept
        end

        def on_decline
        end
      end
    end
  end
end
