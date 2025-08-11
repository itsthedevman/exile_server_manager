# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    ESM_ID = "452568470765305866"

    def self.community_ids
      ESM.cache.fetch("community_ids", expires_in: ESM.config.cache.community_ids) do
        ESM::Database.with_connection { pluck(:community_id) }
      end
    end

    def logging_channel
      ESM.bot.channel(logging_channel_id)
    rescue
      nil
    end

    def discord_server
      ESM.bot.server(guild_id)
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

      ESM.bot.deliver(message, to: channel)
    end

    def modifiable_by?(guild_member)
      return true if guild_member.permission?(:administrator) || guild_member.owner?

      # Check for roles
      dashboard_access_role_ids.any? { |role_id| guild_member.role?(role_id) }
    end
  end
end
