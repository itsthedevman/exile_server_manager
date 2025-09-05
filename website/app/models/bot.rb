# frozen_string_literal: true

class Bot
  #
  # Generates and returns the invite URL for the bot.
  #
  # @return [String] the invite URL for the bot
  #
  def self.invite_url
    client_id = Rails.application.credentials.discord.id

    redirect_uri = URI.encode_uri_component(
      Rails.env.production? ? "https://esmbot.com" : "http://localhost:3000"
    )

    "https://discordapp.com/api/oauth2/authorize?client_id=#{client_id}&permissions=125952&redirect_uri=#{redirect_uri}&scope=bot"
  end

  #
  # @return [DRb::DRbObject] The DRb connection to the bot API server
  #
  def self.instance
    DRb::DRbObject.new_with_uri("druby://localhost:3002")
  end

  #
  # Accepts a request and triggers any logic required by the command
  #
  # @param id [String, Integer] The database ID of the request to accept
  # @return [void]
  #
  def self.accept_request(id)
    instance.requests_accept(id: id)
  end

  #
  # Gets a channel by its ID with optional filtering
  #
  # @param channel_id [String] The Discord channel ID
  # @param filters [Hash] Optional filters to apply
  # @option filters [String] :community_id Restricts search to this community's guild
  # @option filters [String] :user_id Requires channel to be readable by this user
  # @return [Hash, nil] Channel data hash or nil if not found/accessible
  #
  def self.channel(channel_id, **filters)
    instance.channel(**filters.merge(id: channel_id))
  end

  #
  # Returns the channels for a guild that the bot has send permissions for
  #
  # @param community_id [String, Integer] The database ID for the community
  # @param user_id [String, Integer, nil] Optional user ID to check read permissions
  # @return [Array<Array>] Grouped channels array with categories and their children
  #
  def self.community_channels(community_id, user_id: nil)
    instance.community_channels(id: community_id, user_id: user_id) || []
  end

  #
  # Checks if a user can modify a community
  #
  # @param community_id [String, Integer] The community's database ID
  # @param user_id [String, Integer] The user's database ID
  # @return [Boolean] True if user can modify the community, false otherwise
  #
  def self.community_modifiable_by?(community_id, user_id)
    instance.community_modifiable_by?(id: community_id, user_id: user_id) || false
  end

  #
  # Returns the roles for a community
  #
  # @param community_id [String, Integer] The community's database ID
  # @return [Array<Hash>] Array of role hashes with id, name, color, and disabled status
  #
  def self.community_roles(community_id)
    instance.community_roles(id: community_id) || []
  end

  #
  # Returns the users for a community
  #
  # @param community_id [String, Integer] The community's database ID
  # @return [Array<Hash>] Array of user data hashes
  #
  def self.community_users(community_id)
    instance.community_users(id: community_id) || []
  end

  #
  # Declines a request and triggers any logic required by the command
  #
  # @param id [String, Integer] The database ID of the request to decline
  # @return [void]
  #
  def self.decline_request(id)
    instance.requests_decline(id: id)
  end

  #
  # Deletes a community from the database and forces ESM to leave it
  #
  # @param community_id [String, Integer] The community's database ID
  # @param user_id [String, Integer] The user's database ID (used for permission check)
  # @return [Boolean] True if deletion was successful, false otherwise
  #
  def self.delete_community(community_id, user_id)
    instance.community_delete(id: community_id, user_id: user_id) || false
  end

  #
  # Forces a server to reconnect after an ID change
  #
  # @param id [String, Integer] The new server ID
  # @param old_id [String] The old server ID to disconnect
  # @return [void]
  #
  def self.reconnect_server(id, old_id)
    instance.servers_reconnect(id: id, old_id: old_id)
  end

  #
  # Sends a message to a Discord channel
  #
  # @param channel_id [String] The Discord channel ID to send the message to
  # @param message [Hash, String] The message data (will be converted to JSON)
  # @return [void]
  #
  def self.send_message(channel_id:, message:)
    instance.channel_send(id: channel_id, message: message.to_json)
  end

  #
  # Updates a server by sending it the initialization package again
  #
  # @param id [String, Integer] The database ID of the server to update
  # @return [void]
  #
  def self.update_server(id)
    instance.servers_update(id: id)
  end

  #
  # Returns community IDs that a user is part of
  #
  # @param user_id [String, Integer] The user's database ID
  # @param guild_ids [Array<String>] The Discord guild IDs to check
  # @param check_for_perms [Boolean] Whether to check if user has modification permissions
  # @return [Array<Integer>] Array of community database IDs
  #
  def self.user_community_permissions(user_id, guild_ids)
    instance.user_community_permissions(id: user_id, guild_ids:) || []
  end

  #
  # Returns if the server is connected or not
  #
  # @param server_id [String, Integer] The server's ID
  # @return [Boolean]
  #
  def self.server_connected?(server_id)
    instance.servers_connected(id: server_id)
  end
end
