# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    #
    # Whether this community is the developer's home guild.
    #
    # Drives developer-only behavior such as the ESM-branded welcome message
    # on member join and cross-community command access for support work.
    # The reference guild ID comes from `ESM.config.developer_guild_id`
    # (typically wired via the `DEVELOPER_GUILD_ID` env var).
    #
    # @return [Boolean] true when this community's `guild_id` matches the
    #   configured developer guild
    #
    def esm_community?
      guild_id.present? && guild_id == ESM.config.developer_guild_id
    end

    #
    # The Discord channel this community logs bot events to, resolved from `logging_channel_id`.
    #
    # @return [Discordrb::Channel, nil] the channel, or nil when none is configured or the bot
    #   can't resolve it
    #
    def logging_channel
      ESM.discord_bot.channel(logging_channel_id)
    rescue
      nil
    end

    #
    # The Discord server (guild) backing this community, resolved from `guild_id`.
    #
    # @return [Discordrb::Server, nil] the server, or nil when the bot can't resolve it
    #
    def discord_server
      ESM.discord_bot.server(guild_id)
    rescue
      nil
    end

    #
    # Delivers a bot event to this community's logging channel, but only when the community has
    # opted into that event type.
    #
    # Each event maps to a per-community toggle (`log_xm8_event`, `log_discord_log_event`,
    # `log_reconnect_event`, `log_error_event`); the message is dropped when the matching toggle
    # is off or no logging channel is configured.
    #
    # @param event [Symbol] the event category (:xm8, :discord_log, :reconnect, :error)
    # @param message [String, ESM::Embed] the content to log
    #
    # @raise [ESM::Exception::Error] when event is not a recognized category
    #
    def log_event(event, message)
      return if logging_channel_id.blank?

      # Only allow logging events to logging channel if permission has been given
      case event
      when :xm8
        return if !log_xm8_event
      when :discord_log
        return if !log_discord_log_event
      when :reconnect
        return if !log_reconnect_event
      when :error
        return if !log_error_event
      else
        raise ESM::Exception::Error, "Attempted to log :#{event} to #{guild_id} without explicit permission.\nMessage:\n#{message}"
      end

      # Check this first to avoid an infinite loop if the bot cannot send a message to this channel
      # since this method is called from the #deliver method for this exact reason.
      channel = logging_channel
      return if channel.nil?

      ESM.discord_bot.deliver(message, to: channel)
    end

    #
    # Whether the given guild member is allowed to change this community's settings.
    #
    # Guild administrators and the owner always qualify; everyone else must hold one of the
    # configured dashboard-access roles.
    #
    # @param guild_member [Discordrb::Member, nil] the member to authorize
    #
    # @return [Boolean] true when the member may modify the community
    #
    def modifiable_by?(guild_member)
      # A user with no membership in this guild can't modify the community.
      return false if guild_member.nil?
      return true if guild_member.permission?(:administrator) || guild_member.owner?

      dashboard_access_role_ids.any? { |role_id| guild_member.role?(role_id) }
    end

    #
    # The users who hold territory-admin rights in this community: members with a Discord
    # administrator role or one of the community's configured territory-admin roles, plus the guild
    # owner. Lets those users skip the add-consent request (arma still enforces the actual rights).
    #
    # Results are cached for 5 hours and force-refreshed on server boot. Since the majority of
    # communities only run one server, forcing a miss isn't a big deal; most servers also follow a
    # 3 hour restart window, so the 5 hour expiration is more of a safety thing.
    #
    # @param force [Boolean] when true, bypasses the cache and recomputes
    #
    # @return [ActiveRecord::Relation<ESM::User>] the territory-admin users, or none when the guild
    #   can't be resolved
    #
    def territory_admin_users(force: false)
      server = discord_server
      return ESM::User.none if server.nil?

      user_ids =
        ESM.cache.fetch(territory_admin_users_cache_key, expires_in: 5.hours, force:) do
          # Get all roles with administrator or that are set as territory admins
          roles = server.roles.select do |role|
            role.permissions.administrator || territory_admin_ids.include?(role.id.to_s)
          end

          # Get all of the user's discord IDs who have these roles
          discord_ids = roles.flat_map do |role|
            role.users.map { |user| user.id.to_s }
          end

          # Pluck all the steam UIDs we have, including the guild owners
          ESM::User.where(discord_id: discord_ids + [server.owner.id.to_s]).where.not(steam_uid: nil).pluck(:id)
        end

      ESM::User.where(id: user_ids)
    end
  end
end
