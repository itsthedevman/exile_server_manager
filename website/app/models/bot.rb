# frozen_string_literal: true

##
# Thin facade over {ESM::IpcClient}. Every class method here maps to one NATS
# action handled by the bot service. Public signatures are preserved from the
# DRb era so controllers don't change.
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
  # Accepts a request and triggers any logic required by the originating command.
  #
  # @param id [String, Integer] the request's database ID
  # @return [Object, nil] handler result
  #
  def self.accept_request(id)
    ESM::IpcClient.call(:requests_accept, id: id)
  end

  ##
  # Declines a request and triggers any logic required by the originating command.
  #
  # @param id [String, Integer] the request's database ID
  # @return [Object, nil] handler result
  #
  def self.decline_request(id)
    ESM::IpcClient.call(:requests_decline, id: id)
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
    ESM::IpcClient.call(:channel, **filters.merge(id: channel_id))
  end

  ##
  # Returns text channels for a community, grouped by category, filtered to
  # channels the bot (and optional user) can read/send in.
  #
  # @param community_id [String, Integer] the community's database ID
  # @param user_id [String, Integer, nil] optional user to check read perms for
  # @return [Array<Array>]
  #
  def self.community_channels(community_id, user_id: nil)
    ESM::IpcClient.call(:community_channels, id: community_id, user_id: user_id) || []
  end

  ##
  # Returns whether the user can modify the community.
  #
  # @param community_id [String, Integer]
  # @param user_id [String, Integer]
  # @return [Boolean]
  #
  def self.community_modifiable_by?(community_id, user_id)
    ESM::IpcClient.call(:community_modifiable_by, id: community_id, user_id: user_id) || false
  end

  ##
  # Returns the community's selectable roles (excludes admin roles + @everyone).
  #
  # @param community_id [String, Integer]
  # @return [Array<Hash>] each hash: `{id:, name:, color:, disabled:}`
  #
  def self.community_roles(community_id)
    ESM::IpcClient.call(:community_roles, id: community_id) || []
  end

  ##
  # Returns the community's Discord users.
  #
  # @param community_id [String, Integer]
  # @return [Array<Hash>]
  #
  def self.community_users(community_id)
    ESM::IpcClient.call(:community_users, id: community_id) || []
  end

  ##
  # Removes a community: the bot leaves the guild and the record is destroyed.
  # Returns false when the user lacks modify rights.
  #
  # @param community_id [String, Integer]
  # @param user_id [String, Integer]
  # @return [Boolean]
  #
  def self.delete_community(community_id, user_id)
    ESM::IpcClient.call(:community_delete, id: community_id, user_id: user_id) || false
  end

  ##
  # Disconnects a server using its previous ID after a community renamed itself.
  # The Arma DLL reconnects automatically against the new ID.
  #
  # @param id [String, Integer] new server database ID
  # @param old_id [String] previous server ID
  # @return [Object, nil]
  #
  def self.reconnect_server(id, old_id)
    ESM::IpcClient.call(:servers_reconnect, id: id, old_id: old_id)
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
    ESM::IpcClient.call(:channel_send, id: channel_id, message: message)
  end

  ##
  # Pushes a fresh init package to a connected server so settings changes take
  # effect without a full disconnect.
  #
  # @param id [String, Integer] the server's database ID
  # @return [Object, nil]
  #
  def self.update_server(id)
    ESM::IpcClient.call(:servers_update, id: id)
  end

  ##
  # Returns per-community modify permissions for the user across the given guilds.
  #
  # @param user_id [String, Integer]
  # @param guild_ids [Array<String>]
  # @return [Array<Hash>] each `{id:, modifiable:}`
  #
  def self.user_community_permissions(user_id, guild_ids)
    ESM::IpcClient.call(:user_community_permissions, id: user_id, guild_ids: guild_ids) || []
  end

  ##
  # Returns whether the named server currently has a live connection to the bot.
  #
  # @param server_id [String, Integer]
  # @return [Boolean, nil]
  #
  def self.server_connected?(server_id)
    ESM::IpcClient.call(:servers_connected, id: server_id)
  end
end
