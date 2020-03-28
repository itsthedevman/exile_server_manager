# frozen_string_literal: true

module ESM
  module Command
    module Development
      class Eval < ESM::Command::Base
        type :development
        requires :dev

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :code, regex: /.*/, preserve: true, multiline: true, description: "Code to execute"

        def discord
          response = eval @arguments.code # rubocop:disable Security/Eval
          "Input:\n```ruby\n#{@arguments.code}\n```\nOutput:\n```ruby\n#{response}\n```"
        rescue StandardError => e
          "An error occurred: ```#{e.message}```"
        end
      end
    end
  end
end
