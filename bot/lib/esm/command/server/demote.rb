# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Demote < ESM::Command::Base
        set_type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :territory_id
        argument :target

        def on_execute
          # Check for registered target_user. A steam_uid is valid here
          @checks.registered_target_user! if target_user.is_a?(Discordrb::User)

          deliver!(
            function_name: "demotePlayer",
            territory_id: @arguments.territory_id,
            target_uid: target_uid,
            uid: current_user.steam_uid
          )
        end

        def on_response(_, _)
          message = I18n.t(
            "commands.demote.success_message",
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
