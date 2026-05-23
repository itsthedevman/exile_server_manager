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

    def self.community_ids
      ESM.cache.fetch("community_ids", expires_in: ESM.config.cache.community_ids) do
        ESM::Database.with_connection { pluck(:community_id) }
      end
    end

    def logging_channel
      ESM.discord_bot.channel(logging_channel_id)
    rescue
      nil
    end

    def discord_server
      ESM.discord_bot.server(guild_id)
    rescue
      nil
    end

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

    def modifiable_by?(guild_member)
      # A user with no membership in this guild can't modify the community.
      return false if guild_member.nil?

      return true if guild_member.permission?(:administrator) || guild_member.owner?

      dashboard_access_role_ids.any? { |role_id| guild_member.role?(role_id) }
    end
  end
end
