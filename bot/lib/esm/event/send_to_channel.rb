# frozen_string_literal: true

module ESM
  module Event
    class SendToChannel
      def initialize(server, message)
        @server = server
        @message = message
      end

      def run!
        check_for_access!

        # If the content is a hashmap, the data is for an embed
        content = @message.data.content
        message =
          if (embed = ESM::Arma::HashMap.from(content)) && embed.present?
            build_embed(embed)
          else
            "*Sent from `#{@server.server_id}`*\n#{content}"
          end

        ESM.bot.deliver(message, to: @channel)
      rescue ESM::Exception::CheckFailure => e
        @server.log_error(e.message)
      end

      private

      def check_for_access!
        @message.data.id.delete_prefix!("#") if @message.data.id.starts_with?("#")

        discord_server = @server.community.discord_server
        @channel = discord_server.channels.find do |channel|
          channel.id.to_s == @message.data.id || channel.name.match?(/#{@message.data.id}/i)
        end

        raise ESM::Exception::CheckFailure, I18n.t("exceptions.extension.invalid_send_to_channel", channel_id: @message.data.id) if @channel.nil?
      end

      def build_embed(embed_data)
        ESM::Embed.from_hash(embed_data) do |e|
          e.set_author(name: "Sent from #{@server.server_id}") if e.author.nil?
        end
      end
    end
  end
end
