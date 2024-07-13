# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Remove < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:target]
        argument :target, display_name: :whom

        # See Argument::TEMPLATES[:territory_id]
        argument :territory_id, display_name: :from

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_namespace :territory, command_name: :remove_player
        command_type :player

        #################################

        def on_execute
          check_for_registered_target_user! if target_user.is_a?(ESM::User)

          response = call_sqf_function(
            "ESMs_command_remove",
            territory_id: arguments.territory_id
          )

          embed = embed_from_message!(response)
          reply(embed)
        end

        module V1
          def on_execute
            # Check for registered target_user
            check_for_registered_target_user! if target_user.is_a?(ESM::User)

            deliver!(
              function_name: "removePlayerFromTerritory",
              territory_id: arguments.territory_id,
              target_uid: target_uid,
              uid: current_user.steam_uid
            )
          end

          def on_response
            message = I18n.t(
              "commands.remove.success_message",
              user: current_user.mention,
              target_uid: target_uid,
              territory_id: arguments.territory_id,
              server: target_server.server_id
            )

            reply(ESM::Embed.build(:success, description: message))
          end
        end
      end
    end
  end
end
