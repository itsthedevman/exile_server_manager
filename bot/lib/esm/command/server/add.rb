# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Add < ESM::Command::Base
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
          # Either a memer or admin trying to add themselves. Either way, the arma server handles this.
          return request_accepted if same_user?

          # Checks for a registered target user. This also keeps people from adding via steam_uid only
          @checks.registered_target_user!

          @checks.pending_request!
          add_request(
            to: target_user,
            description: I18n.t(
              "commands.add.request_description",
              current_user: current_user.distinct,
              target_user: target_user.mention,
              territory_id: @arguments.territory_id,
              server_id: target_server.server_id
            )
          )

          embed = ESM::Embed.build(:success, description: I18n.t("commands.request.sent"))
          reply(embed)
        end

        def server
          # Send the success message to the requestee (which can be the requestor)
          embed = ESM::Embed.build(:success, description: I18n.t("commands.add.requestee_success", user: target_user.mention, territory_id: @arguments.territory_id))
          ESM.bot.deliver(embed, to: target_user)

          # Don't send essentially the same message twice
          return if same_user?

          # Send a message to the requestor (if they aren't the requestee as well)
          embed = ESM::Embed.build(
            :success,
            description: I18n.t(
              "commands.add.requestor_success",
              current_user: current_user.mention,
              target_user: target_user.distinct,
              territory_id: @arguments.territory_id,
              server_id: target_server.server_id
            )
          )

          reply(embed)
        end

        def request_accepted
          # Request the arma server to add the user
          deliver!(
            function_name: "addPlayerToTerritory",
            territory_id: @arguments.territory_id,
            target_uid: target_user.steam_uid,
            uid: current_user.steam_uid
          )

          # # Don't send the request accepted message if the requestor is the requestee
          # return if same_user?

          # embed = ESM::Embed.build(:success, description: I18n.t("commands.add.requestor_accepted", uuid: @request.uuid_short, target_user: target_user.distinct, territory_id: @arguments.territory_id, server_id: target_server.server_id))

          # reply(embed)
        end
      end
    end
  end
end
