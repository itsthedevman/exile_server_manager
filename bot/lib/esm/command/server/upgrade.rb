# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Upgrade < ESM::Command::Base
        set_type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :territory_id

        def on_execute
          deliver!(
            function_name: "upgradeTerritory",
            territory_id: @arguments.territory_id,
            uid: current_user.steam_uid
          )
        end

        def on_response(_, _)
          return if @response.blank?

          message = I18n.t(
            "commands.upgrade.success_message",
            user: current_user.mention,
            territory_id: @arguments.territory_id,
            cost: @response.cost.to_poptab,
            level: @response.level,
            range: @response.range,
            locker: @response.locker.to_poptab
          )

          reply(ESM::Embed.build(:success, description: message))
        end
      end
    end
  end
end
