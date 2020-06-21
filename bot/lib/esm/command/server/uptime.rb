# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Uptime < ESM::Command::Base
        type :player
        aliases :up, :up_time

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def discord
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.uptime.server_uptime", server: target_server.server_id, time: target_server.uptime)
            end

          reply(embed)
        end
      end
    end
  end
end
