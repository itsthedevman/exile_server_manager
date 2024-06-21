# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Upgrade < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:territory_id]
        argument :territory_id, display_name: :territory

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_type :player

        #################################

        def on_execute
          response = call_sqf_function(
            "ESMs_command_upgrade",
            territory_id: arguments.territory_id
          )

          embed_data = response.data.to_h
          reply(ESM::Embed.from_hash(embed_data))
        end

        module V1
          def on_execute
            deliver!(
              function_name: "upgradeTerritory",
              territory_id: arguments.territory_id,
              uid: current_user.steam_uid
            )
          end

          def on_response
            return if @response.blank?

            message = I18n.t(
              "commands.upgrade.success_message",
              user: current_user.mention,
              territory_id: arguments.territory_id,
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
end
