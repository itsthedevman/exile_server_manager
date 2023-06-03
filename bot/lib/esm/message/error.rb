# frozen_string_literal: true

module ESM
  class Message
    class Error
      attr_reader :type, :content

      def initialize(type, content)
        @type = type.to_sym
        @content = content.to_s
      end

      def to_h
        {
          type: @type,
          content: @content
        }
      end

      def to_s(message)
        case type
        when :code
          command = message.attributes.command

          replacements = {
            user: command&.current_user&.mention,
            target: command&.target_user&.mention,
            prefix: command&.prefix,
            message_id: message.id,
            server_id: message.attributes.server_id,
            type: message.type,
            data_type: message.data_type,
            mdata_type: message.metadata_type,
            data_territory_id: message.data_attributes[:content].dig(:territory, :encoded, :id)
          }

          # Add the data and metadata to the replacements
          # For example, if data has two attributes: "steam_uid" and "discord_id", this will define two replacements:
          #     "data_steam_uid", and "data_discord_id"
          #
          # Same for metadata's attributes. Except the key prefix is "mdata_"
          message.data_attributes[:content].each do |key, value|
            replacements["data_#{key}".to_sym] = value
          end

          message.metadata_attributes[:content].each do |key, value|
            replacements["mdata_#{key}".to_sym] = value
          end

          # Call the exception with the replacements
          I18n.t("exceptions.extension.#{content}", **replacements)
        when :message
          content
        else
          I18n.t("exceptions.extension.default", type: type)
        end
      end
    end
  end
end
