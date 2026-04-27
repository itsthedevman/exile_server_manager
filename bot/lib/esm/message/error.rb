# frozen_string_literal: true

module ESM
  class Message
    class Error
      attr_reader :type, :content

      def initialize(message, type, content)
        @message = message
        @type = type.to_sym
        @content = content.to_s
      end

      def to_h
        {
          type: @type,
          content: @content
        }
      end

      def to_s
        case type
        when :code
          metadata = @message.metadata

          replacements = {
            message_id: @message.id,
            type: @message.type,
            server_id: metadata.server_id,
            user: metadata.player&.discord_mention,
            target: metadata.target&.discord_mention
          }

          # Add the data and metadata to the replacements
          # For example, if data has two attributes: "steam_uid" and "discord_id", this will define two replacements:
          #     "data_steam_uid", and "data_discord_id"
          @message.data.to_h.each do |key, value|
            replacements[:"data_#{key}"] = value
          end

          # Call the exception with the replacements
          I18n.t(
            "exceptions.extension.#{content}",
            default: I18n.t("exceptions.extension.default", type: content),
            **replacements
          )
        when :message
          content
        else
          I18n.t("exceptions.extension.default", type: type)
        end
      end
    end
  end
end
