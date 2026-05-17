# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reset < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # See Argument::TEMPLATES[:target]
        # Optional: Omitting resets all
        argument :target, display_name: :whom, required: false

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :reset_player
        command_type :admin

        limit_to :text

        skip_action :nil_target_user

        #################################

        def on_execute
          check_for_registered_target_user! if target_user.is_a?(ESM::User)
          check_for_pending_request!

          # Create a confirmation request to the requestee
          add_request(
            to: current_user,
            description: I18n.t(
              "commands.reset.request_description",
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
          if target_user
            query_exile_database!("reset_player", uid: target_user.steam_uid)
          else
            query_exile_database!("reset_all")
          end

          description =
            if target_user
              I18n.t(
                "commands.reset.success_message_target",
                user: current_user.mention,
                target: target_user.mention
              )
            else
              I18n.t("commands.reset.success_message_all", user: current_user.mention)
            end

          embed = ESM::Embed.build(:success, description:)
          reply(embed)
        end

        module V1
          def on_response
            embed =
              if target_user.present?
                if @response.success
                  ESM::Embed.build(:success, description: I18n.t("commands.reset.success_message_target", user: current_user.mention, target: target_user.mention))
                else
                  ESM::Embed.build(:error, description: I18n.t("commands.reset.failure_message_target", user: current_user.mention, target: target_user.mention))
                end
              elsif @response.success
                ESM::Embed.build(:success, description: I18n.t("commands.reset.success_message_all", user: current_user.mention))
              else
                ESM::Embed.build(:error, description: I18n.t("commands.reset.failure_message_all", user: current_user.mention))
              end

            reply(embed)
          end

          def on_request_accepted
            deliver!(
              query: target_user.present? ? "reset_player" : "reset_all",
              targetUID: target_user&.steam_uid
            )
          end
        end
      end
    end
  end
end
