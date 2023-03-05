# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module General
      class Register < ESM::Command::Base
        set_type :player

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        def on_execute
          message =
            if current_user.esm_user.registered?
              already_registered_message
            else
              registration_message
            end

          reply(message)
        end

        private

        def already_registered_message
          ESM::Embed.build do |e|
            e.description = I18n.t("commands.register.already_registered", user: current_user.mention, prefix: prefix)
          end
        end

        def registration_message
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.not_registered", user: current_user.mention, full_username: current_user.distinct)
          end
        end
      end
    end
  end
end
