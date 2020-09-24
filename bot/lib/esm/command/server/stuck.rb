# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Stuck < ESM::Command::Base
        type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def discord
          # Create a confirmation request to the requestee
          @checks.pending_request!
          add_request(
            to: current_user,
            description: I18n.t(
              "commands.stuck.request_description",
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
            if @response.success
              ESM::Embed.build(:success, description: I18n.t("commands.stuck.success_message", user: current_user.mention))
            else
              ESM::Embed.build(:error, description: I18n.t("commands.stuck.failure_message", user: current_user.mention, server: target_server.server_id))
            end

          reply(embed)
        end

        def request_accepted
          # Send request to the server
          deliver!(query: "reset_player", targetUID: current_user.steam_uid)
        end
      end
    end
  end
end
