# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Restore < ESM::Command::Base
        type :admin
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :territory_id

        def discord
          @checks.owned_server!
          deliver!(query: "restore", territory_id: @arguments.territory_id)
        end

        def server
          embed =
            if @response.success
              ESM::Embed.build(
                :success,
                description: I18n.t("commands.restore.success_message", user: current_user.mention, territory_id: @arguments.territory_id)
              )
            else
              ESM::Embed.build(
                :error,
                description: I18n.t(
                  "commands.restore.failure_message",
                  user: current_user.mention,
                  territory_id: @arguments.territory_id,
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
