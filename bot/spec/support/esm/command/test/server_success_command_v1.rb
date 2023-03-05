# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ServerSuccessCommandV1 < ESM::Command::Base
        set_type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :nullable, regex: /.*/, description: "commands.server_success_command.arguments.nullable", default: nil

        def on_execute
          deliver!
          self
        end

        def on_response(_, _)
          reply("Yaay")
        end
      end
    end
  end
end
