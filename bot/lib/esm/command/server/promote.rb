# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Promote < ESM::Command::Base
        type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :territory_id
        argument :target

        def discord
          # Check for registered target_user
          @checks.registered_target_user!

          deliver!(
            function_name: "promotePlayer",
            territory_id: @arguments.territory_id,
            uid: current_user.steam_uid,
            target_uid: target_uid
          )
        end

        def server
          message = I18n.t(
            "commands.promote.success_message",
            user: current_user.mention,
            target_uid: target_uid,
            territory_id: @arguments.territory_id,
            server: target_server.server_id
          )

          reply(ESM::Embed.build(:success, description: message))
        end
      end
    end
  end
end
