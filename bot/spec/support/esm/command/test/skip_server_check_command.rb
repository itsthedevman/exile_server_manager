# frozen_string_literal: true

module ESM
  module Command
    module Test
      class SkipServerCheckCommand < ESM::Command::Base
        set_type :player

        skip_check :connected_server

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def on_execute
          "Hello"
        end

        def on_response(_, _)
        end
      end
    end
  end
end
