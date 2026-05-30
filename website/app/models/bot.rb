# frozen_string_literal: true

##
# Thin facade over {ESM::Service::API} for bot actions that aren't a natural fit
# on a domain model. Generic Discord primitives live here; everything tied to a
# Community/Server/User/Request has moved onto that model.
#
# Errors are intentionally not rescued: callers (controllers, jobs) decide
# whether a transport failure or remote error should be user-visible.
#
class Bot
  ##
  # Generates and returns the bot's Discord invite URL.
  #
  # @return [String]
  #
  def self.invite_url
    client_id = Settings.discord.id

    redirect_uri = URI.encode_uri_component(
      Rails.env.production? ? "https://esmbot.com" : "http://localhost:3000"
    )

    "https://discordapp.com/api/oauth2/authorize?client_id=#{client_id}&permissions=125952&redirect_uri=#{redirect_uri}&scope=bot"
  end

  ##
  # Resolves a Discord channel by ID with optional filtering.
  #
  # @param channel_id [String] the Discord channel ID
  # @param filters [Hash] optional filters
  # @option filters [String] :community_id restrict to this community's guild
  # @option filters [String] :user_id require the user can read the channel
  # @return [Hash, nil] channel data hash or nil if not found/accessible
  #
  def self.channel(channel_id, **filters)
    ESM::Service::API.call(:channel, **filters.merge(id: channel_id))
  end

  ##
  # Sends a message to a Discord channel. Accepts an Embed-shaped hash or a
  # plain text string.
  #
  # @param channel_id [String]
  # @param message [Hash, String]
  # @return [Object, nil]
  #
  def self.send_message(channel_id:, message:)
    ESM::Service::API.call(:channel_send, id: channel_id, message: message)
  end
end
