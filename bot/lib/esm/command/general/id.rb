# frozen_string_literal: true

module ESM
  module Command
    module General
      class Id < ESM::Command::Base
        type :player
        limit_to :text

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        def discord
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.id.embed.description", community_name: current_community.name, community_id: current_community.community_id)
              e.add_field(
                name: I18n.t("commands.id.embed.field.name"),
                value: I18n.t("commands.id.embed.field.value", prefix: prefix, community_id: current_community.community_id)
              )
            end

          reply(embed)
        end
      end
    end
  end
end
