# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Stuck < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_type :player

        #################################

        def on_execute
          check_for_pending_request!

          # Create a confirmation request to the requestee
          add_request(
            to: current_user,
            description: I18n.t(
              "commands.stuck.request_description",
              user: current_user.mention,
              server: target_server.server_id
            )
          )

          # Remind them to check their PMs
          embed = ESM::Embed.build(
            :success,
            description: I18n.t("commands.request.check_pm", user: current_user.mention)
          )

          reply(embed)
        end

        def on_request_accepted
          query_exile_database!("reset_player", uid: current_user.steam_uid)

          embed = ESM::Embed.build(
            :success,
            description: I18n.t("commands.stuck.success_message", user: current_user.mention)
          )

          reply(embed)
        end

        module V1
          def on_response
            embed =
              if @response.success
                ESM::Embed.build(:success, description: I18n.t("commands.stuck.success_message", user: current_user.mention))
              else
                ESM::Embed.build(:error, description: I18n.t("commands.stuck.failure_message", user: current_user.mention, server: target_server.server_id))
              end

            reply(embed)
          end

          def on_request_accepted
            # Send request to the server
            deliver!(query: "reset_player", targetUID: current_user.steam_uid)
          end
        end
      end
    end
  end
end
