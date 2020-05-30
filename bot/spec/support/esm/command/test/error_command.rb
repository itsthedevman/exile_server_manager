# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Test
      class ErrorCommand < ESM::Command::Base
        type :player

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        def discord
          raise StandardError, "Oops"
        end
      end
    end
  end
end
