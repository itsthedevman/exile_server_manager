# frozen_string_literal: true

module ESM
  class Xm8Notification
    class Custom < Xm8Notification
      def valid?
        Embed.from_hash!(content.to_h)
      rescue ArgumentError
        false
      end

      def to_embed
        Embed.from_hash!(content.to_h).tap do |e|
          e.footer = "[#{server.server_id}] #{server.server_name}"
        end
      end
    end
  end
end
