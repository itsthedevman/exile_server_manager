# frozen_string_literal: true

module ESM
  module Command
    module General
      class Whois < ESM::Command::Base
        type :admin

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :target

        def discord
          load_steam_info

          ESM::Embed.build do |e|
            add_discord_info(e)
            add_steam_info(e) if @steam_success
          end
        end

        #########################
        # Command Methods
        #########################
        def load_steam_info
          @steam = ESM::Service::Steam.new(target_user.steam_uid)
          @player_info = @steam.player_info
          @player_bans = @steam.player_bans
          @steam_success = @player_info.present? || @player_bans.present?
        end

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
          e.add_field(value: I18n.t("commands.whois.steam.header"))

          if @player_info.present?
            e.thumbnail = @player_info.avatarfull
            e.add_field(name: I18n.t("commands.whois.steam.id"), value: @player_info.steamid, inline: true)
            e.add_field(
              name: I18n.t("commands.whois.steam.username"),
              value: "[#{@player_info.personaname}](#{@player_info.profileurl})",
              inline: true
            )
            e.add_field(name: I18n.t("commands.whois.steam.visibility"), value: @steam.profile_visibility, inline: true)
            e.add_field(name: I18n.t("commands.whois.steam.created_at"), value: @steam.profile_created_at.strftime("%c"), inline: true) if @steam.profile_created_at.present?
          end

          return if @player_bans.blank?

          e.add_field(
            name: I18n.t("commands.whois.steam.community_banned"),
            value: @player_bans.CommunityBanned ? I18n.t("yes") : I18n.t("no"),
            inline: true
          )

          e.add_field(
            name: I18n.t("commands.whois.steam.vac_banned"),
            value: @player_bans.VACBanned ? I18n.t("yes") : I18n.t("no"),
            inline: true
          )

          return if !@player_bans.VACBanned

          e.add_field(name: I18n.t("commands.whois.steam.number_of_vac_bans"), value: @player_bans.NumberOfVACBans, inline: true)
          e.add_field(name: I18n.t("commands.whois.steam.days_since_vac_ban"), value: @player_bans.DaysSinceLastBan, inline: true)
        end
      end
    end
  end
end
