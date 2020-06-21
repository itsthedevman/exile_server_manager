# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module General
      class SteamUid < ESM::Command::Base
        type :player
        aliases :uid
        requires :registration

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        def discord
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.steam_uid.response", user: current_user.mention, steam_uid: current_user.steam_uid)
            end

          reply(embed)
        end
      end
    end
  end
end
