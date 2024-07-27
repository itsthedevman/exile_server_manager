# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Restore < ApplicationCommand
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

        change_attribute :allowlist_enabled, default: true

        command_namespace :territory, :admin
        command_type :admin

        limit_to :text

        #################################

        def on_execute
          check_for_owned_server!
          run_database_query("restore", territory_id: arguments.territory_id)
        end

        module V1
          def on_execute
            check_for_owned_server!
            deliver!(query: "restore", territory_id: arguments.territory_id)
          end

          def on_response
            embed =
              if @response.success
                ESM::Embed.build(
                  :success,
                  description: I18n.t("commands.restore.success_message", user: current_user.mention, territory_id: arguments.territory_id)
                )
              else
                ESM::Embed.build(
                  :error,
                  description: I18n.t(
                    "commands.restore.failure_message",
                    user: current_user.mention,
                    territory_id: arguments.territory_id,
                    server: target_server.server_id
                  )
                )

              end

            reply(embed)
          end
        end
      end
    end
  end
end
