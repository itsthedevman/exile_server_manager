# frozen_string_literal: true

module ESM
  module Command
    module Community
      class Whois < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:target]
        argument :target, display_name: :whom

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :community, :admin, command_name: :find_player
        command_type :admin

        # Useful command and some people don't want to register
        does_not_require :registration

        limit_to :text

        #################################

        def on_execute
          check_for_user_access!

          embed =
            ESM::Embed.build do |e|
              add_discord_info(e) if target_user.is_a?(ESM::User)
              add_steam_info(e)
            end

          reply(embed)
        end

        # An absent :discord is ambiguous on its own - the target may have no ESM account, may have one they never
        # linked a Steam UID to, or may simply not be in the caller's Discord. Those are three different answers, and
        # the caller can only tell them apart if the flags come along to say which.
        def on_website_execute
          data = {
            steam: target_user.steam_data.to_h,
            has_account: target_user.is_a?(ESM::User),
            registered: target_user.registered?
          }

          data[:discord] = target_user.discord_user.to_h if data[:has_account] && user_has_access?

          reply(data)
        end

        private

        # Argument e is an embed
        def add_discord_info(e)
          discord_user = target_user.discord_user
          e.add_field(value: I18n.t("commands.whois.discord.header"))
          e.add_field(name: I18n.t("commands.whois.discord.id"), value: discord_user.id, inline: true)
          e.add_field(name: I18n.t("commands.whois.discord.username"), value: discord_user.distinct, inline: true)
          e.add_field(name: I18n.t("commands.whois.discord.status"), value: discord_user.status.to_s.capitalize, inline: true)
          e.add_field(name: I18n.t("commands.whois.discord.created_at"), value: discord_user.creation_time.strftime("%c"), inline: true)
          e.set_author(name: discord_user.distinct, icon_url: discord_user.avatar_url)
        end

        # Argument e is an embed
        def add_steam_info(e)
          @steam_data = target_user.steam_data

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
          e.add_field(name: I18n.t("commands.whois.steam.days_since_vac_ban"), value: @steam_data.days_since_last_ban, inline: true)
        end

        def user_has_access?
          return true if current_user.developer?

          # This is just a steam uid, go ahead and allow it.
          return true if target_user.is_a?(ESM::User::Ephemeral)

          # Ensure the user in question is a member of the current Discord. This keeps players from inviting ESM and abusing the command to find admins of other servers.
          return true if current_community.discord_server.member(target_user.discord_id.to_i).present?

          false
        end

        def check_for_user_access!
          return if user_has_access?

          raise_error!(:access_denied, user: current_user)
        end
      end
    end
  end
end
