# frozen_string_literal: true

module ESM
  module Event
    class DiscordMessageChannel
      # Unfortunately, this class is bound by the code I wrote 2 years ago. It's very implicit.
      def initialize(connection:, server:, parameters:)
        @server = server
        @message = parameters.message
        @channel_id = parameters.channelID
      end

      def run!
        check_for_access!

        # [String, JSON] If array, [title, description, fields(Array)[name, value, inline], color[name, hex]]
        # Attempt to parse the JSON. to_h will return nil if it fails
        data = @message.to_h

        message =
          if data.nil?
            "**Message from #{@server.server_id}**\n#{@message}"
          else
            build_embed(data)
          end

        ESM.bot.deliver(message, to: @channel_id)
      rescue ESM::Exception::CheckFailure => e
        @server.community.log_event(:discord_log, e.data)
      rescue StandardError
        @server.community.log_event(:discord_log, I18n.t("exceptions.malformed_message", message: @message))
      end

      private

      def check_for_access!
        discord_server = @server.community.discord_server
        channel_ids = discord_server.channels.map(&:id).map(&:to_s)

        raise ESM::Exception::CheckFailure, I18n.t("exceptions.invalid_channel_access", channel_id: @channel_id) if !channel_ids.include?(@channel_id)
      end

      def build_embed(data)
        # Unpack
        title = data.first.to_s
        description = data.second.to_s
        fields = data.third
        color = data.fourth.to_s

        # Build the Embed
        ESM::Embed.build do |e|
          e.set_author(name: "Message from #{@server.server_id}")
          e.title = title
          e.description = description
          e.color =
            if ESM::Regex::HEX_COLOR.match(color)
              color
            elsif ESM::Color::Toast.const_defined?(color.upcase)
              ESM::Color::Toast.const_get(color.upcase)
            else
              ESM::Color.random
            end

          fields.each do |field|
            e.add_field(name: field.first.to_s, value: field.second.to_s, inline: field.third || false)
          end
        end
      end
    end
  end
end
