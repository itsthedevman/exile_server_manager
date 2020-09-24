# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reset < ESM::Command::Base
        type :admin
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :target, default: nil

        def discord
          @checks.registered_target_user!

          # Create a confirmation request to the requestee
          @checks.pending_request!
          add_request(
            to: current_user,
            description: I18n.t(
              "commands.reset.request_description",
              user: current_user.mention,
              server: target_server.server_id
            )
          )

          # Remind them to check their PMs
          embed = ESM::Embed.build(:success, description: I18n.t("commands.request.check_pm", user: current_user.mention))
          reply(embed)
        end

        def server
          embed =
            if target_user.present?
              if @response.success
                ESM::Embed.build(:success, description: I18n.t("commands.reset.success_message_target", user: current_user.mention, target: target_user.mention))
              else
                ESM::Embed.build(:error, description: I18n.t("commands.reset.failure_message_target", user: current_user.mention, target: target_user.mention))
              end
            else
              if @response.success
                ESM::Embed.build(:success, description: I18n.t("commands.reset.success_message_all", user: current_user.mention))
              else
                ESM::Embed.build(:error, description: I18n.t("commands.reset.failure_message_all", user: current_user.mention))
              end
            end

          reply(embed)
        end

        def request_accepted
          deliver!(
            query: target_user.present? ? "reset_player" : "reset_all",
            targetUID: target_user&.steam_uid
          )
        end
      end
    end
  end
end
