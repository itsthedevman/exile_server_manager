# frozen_string_literal: true

class CommandEvent
  def self.create(content, user:, channel_type: :text, channel: nil, guild: nil)
    if channel_type == :text
      channel_id =
        if channel
          channel.is_a?(Discordrb::Channel) ? channel.id : channel.to_s
        else
          ESM::Test.data[user.guild_type][:channels].sample
        end

      guild_id = channel.server.id if channel.is_a?(Discordrb::Channel)
    else
      channel_id = user.discord_user.pm.id
    end

    guild_id = ESM::Test.data[user.guild_type][:server_id] if guild_id.nil?

    data = {
      "id" => nil,
      "content" => content,
      "channel_id" => channel_id,
      "guild_id" => guild_id,
      "pinned" => false,
      "author" => {
        "id" => user.discord_id,
        "username" => user.discord_username
      }
    }

    message = Discordrb::Message.new(data, ESM.bot)
    Discordrb::Commands::CommandEvent.new(message, ESM.bot)
  end
end
