# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Sends a message to a Discord channel (or a user's DM channel when the ID
        # is a user). Accepts an embed hash or a plain string.
        #
        class ChannelSend
          def self.call(id:, message:, **)
            info!(event: "channel:send", id: id, message: message)

            channel = ESM.discord_bot.channel(id) || ESM.discord_bot.user(id)
            channel = channel.pm if channel.is_a?(Discordrb::User)
            return if channel.nil?
            # PM channels carry no per-channel permission model; for everything
            # else (text, news/announcement, threads) require send_messages or
            # we'd silently push to a channel the bot can't write to.
            return if !channel.pm? && !ESM.discord_bot.channel_permission?(:send_messages, channel)

            message = message.parse_json || message if message.is_a?(String)
            message = ESM::Embed.from_hash(message) if message.is_a?(Hash)

            ESM.discord_bot.deliver(message, to: channel)
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot lost access to the channel/guild between cache and send.
            # Silently no-op rather than 500ing the request.
            nil
          end
        end
      end
    end
  end
end
