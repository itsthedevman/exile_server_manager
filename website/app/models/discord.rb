# frozen_string_literal: true

class Discord
  def self.client(...)
    new(...)
  end

  attr_reader :client, :base_url

  def initialize(token = nil)
    auth =
      if token
        "Bearer #{token}"
      else
        "Bot #{Rails.application.credentials.discord[:token]}"
      end

    @client = HTTP.auth(auth)
    @base_url = "https://discord.com/api/v10"
  end

  def guild_channels(guild_id)
    client.get(build_url("/guilds/#{guild_id}/channels"))
  end

  def user_guilds
    client.get(build_url("/users/@me/guilds"))
  end

  private

  def build_url(url)
    "#{base_url}#{url}"
  end
end
