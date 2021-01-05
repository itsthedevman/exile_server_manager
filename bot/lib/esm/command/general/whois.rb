# frozen_string_literal: true

module ESM
  module Command
    module General
      class Whois < ESM::Command::Base
        type :admin
        limit_to :text

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :target

        def discord
          embed =
            ESM::Embed.build do |e|
              add_discord_info(e) if target_user.is_a?(Discordrb::User)
              add_steam_info(e) if target_user.esm_user.registered?
            end

          reply(embed)
        end

        #########################
        # Command Methods
        #########################
        # Argument e is an embed
        def add_discord_info(e)
          e.add_field(value: I18n.t("commands.whois.discord.header"))
          e.add_field(name: I18n.t("commands.whois.discord.id"), value: target_user.id, inline: true)
          e.add_field(name: I18n.t("commands.whois.discord.username"), value: target_user.distinct, inline: true)
          e.add_field(name: I18n.t("commands.whois.discord.status"), value: target_user.status.to_s.capitalize, inline: true)
          e.add_field(name: I18n.t("commands.whois.discord.created_at"), value: target_user.creation_time.strftime("%c"), inline: true)
          e.set_author(name: target_user.distinct, icon_url: target_user.avatar_url)
        end

        # Argument e is an embed
        def add_steam_info(e)
          @steam_data = target_user.esm_user.steam_data

          e.add_field(value: I18n.t("commands.whois.steam.header"))

          e.thumbnail = @steam_data.avatar if @steam_data.avatar
          e.add_field(name: I18n.t("commands.whois.steam.id"), value: target_user.steam_uid, inline: true)

          if @steam_data.username && @steam_data.profile_url
            e.add_field(
              name: I18n.t("commands.whois.steam.username"),
              value: "[#{@steam_data.username}](#{@steam_data.profile_url})",
              inline: true
            )
          end

          e.add_field(name: I18n.t("commands.whois.steam.visibility"), value: @steam_data.profile_visibility, inline: true) if @steam_data.profile_visibility
          e.add_field(name: I18n.t("commands.whois.steam.created_at"), value: @steam_data.profile_created_at.strftime("%c"), inline: true) if @steam_data.profile_created_at

          if @steam_data.community_banned?
            e.add_field(
              name: I18n.t("commands.whois.steam.community_banned"),
              value: @steam_data.community_banned? ? I18n.t("yes") : I18n.t("no"),
              inline: true
            )
          end

          return if !@steam_data.vac_banned?

          e.add_field(
            name: I18n.t("commands.whois.steam.vac_banned"),
            value: @steam_data.vac_banned? ? I18n.t("yes") : I18n.t("no"),
            inline: true
          )

          e.add_field(name: I18n.t("commands.whois.steam.number_of_vac_bans"), value: @steam_data.number_of_vac_bans, inline: true)
          e.add_field(name: I18n.t("commands.whois.steam.days_since_vac_ban"), value: @steam_data.days_since_vac_ban, inline: true)
        end
      end
    end
  end
end
