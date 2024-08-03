# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Add < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:target]
        argument :target, display_name: :whom

        # See Argument::TEMPLATES[:territory_id]
        argument :territory_id, display_name: :to

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_type :player
        command_namespace :territory, command_name: :add_player

        #################################

        def on_execute
          # Either a memer or admin trying to add themselves. Either way, the arma server handles this.
          return on_request_accepted if same_user?

          # Checks for a registered target user.
          # This also keeps people from adding via steam_uid only
          check_for_registered_target_user!
          check_for_pending_request!

          add_request(
            to: target_user,
            description: I18n.t(
              "commands.add.request_description",
              current_user: current_user.distinct,
              target_user: target_user.mention,
              territory_id: arguments.territory_id,
              server_id: target_server.server_id
            )
          )

          embed = ESM::Embed.build(:success, description: I18n.t("commands.request.sent"))
          reply(embed)
        end

        def on_request_accepted
          response = call_sqf_function(
            "ESMs_command_add",
            territory_id: arguments.territory_id
          )

          # Parse both first in case there are errors
          requestee_embed = embed_from_hash!(response.data.requestee)
          requestor_embed = embed_from_hash!(response.data.requestor)

          # Send to the requestee first since they can be the requestor
          ESM.bot.deliver(requestee_embed, to: target_user)

          # And if they are the same person, don't send them the second message
          return if same_user?

          reply(requestor_embed)
        end

        module V1
          def on_request_accepted
            # Request the arma server to add the user
            deliver!(
              function_name: "addPlayerToTerritory",
              territory_id: arguments.territory_id,
              target_uid: target_user.steam_uid,
              uid: current_user.steam_uid
            )
          end

          def on_response
            # Send the success message to the requestee (which can be the requestor)
            embed = ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.add.requestee_success",
                user: target_user.mention,
                territory_id: arguments.territory_id
              )
            )

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
                territory_id: arguments.territory_id,
                server_id: target_server.server_id
              )
            )

            reply(embed)
          end
        end
      end
    end
  end
end
