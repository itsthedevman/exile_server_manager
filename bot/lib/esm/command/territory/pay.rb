# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Pay < ApplicationCommand
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
          response = call_sqf_function!(
            "ESMs_command_pay",
            territory_id: arguments.territory_id
          )

          embed = embed_from_message!(response)
          reply(embed)
        end

        module V1
          def on_execute
            deliver!(function_name: "payTerritory", territory_id: arguments.territory_id, uid: current_user.steam_uid)
          end

          def on_response
            embed =
              ESM::Embed.build do |e|
                e.description = I18n.t(
                  "commands.pay.embed.description",
                  user: current_user.mention,
                  server_id: target_server.server_id,
                  territory_id: arguments.territory_id,
                  cost: @response.payment.to_poptab,
                  locker_amount: @response.locker.to_poptab
                )

                e.color = :green
              end

            reply(embed)
          end
        end
      end
    end
  end
end
