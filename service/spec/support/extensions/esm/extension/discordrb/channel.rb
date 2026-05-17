module Discordrb
  class Channel
    def send_message(content, tts = false, embed = nil, attachments = nil, allowed_mentions = nil, message_reference = nil, components = nil)
      ESM.discord_bot.test_outbox.store(content, self)
    end

    def send_embed(content = "", embed = nil, attachments = nil, tts = false, allowed_mentions = nil, message_reference = nil, components = nil)
      embed ||= Discordrb::Webhooks::Embed.new
      view = Discordrb::Webhooks::View.new

      content = yield(embed, view) if block_given?

      ESM.discord_bot.test_outbox.store(content, self)
    end
  end
end
