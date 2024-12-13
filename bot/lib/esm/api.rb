# frozen_string_literal: true

module ESM
  class API
    def self.run
      port = ESM.config.ports.api
      @instance = DRb::DRbServer.new("druby://localhost:#{port}", new)
    end

    def self.stop
      @instance.stop_service
    end

    # Accepts a request and triggers any logic that is required by the command
    def requests_accept(id:)
      info!(event: "requests:accept", id: id)

      request = ESM::Request.where(id: id).first
      return if request.nil?

      # Respond to the request
      request.respond(true)
    end

    # Declines a request and triggers any logic that is required by the command
    def requests_decline(id:)
      info!(event: "requests:decline", id: id)

      request = ESM::Request.where(id: id).first
      return if request.nil?

      # Respond to the request
      request.respond(false)
    end

    # Updates a server by sending it the initialization package again
    def servers_update(id:)
      info!(event: "servers:update", id: id)

      server = ESM::Server.where(id: id).first
      return if server.nil?

      if server.v2?
        connection = server.connection
        return true if connection.nil?

        connection.close(I18n.t("server_reconnect.reasons.settings_update"))
      else
        connection = ESM::Websocket.connection(server.server_id)
        return true if connection.nil?

        # Tell ESM to update the server with the new details
        ESM::Event::ServerInitializationV1.new(connection: connection, server: server, parameters: {}).update
      end
    end

    # If a community changes their ID, their servers need to disconnect and reconnect
    # id => New ID
    # old_id => Old ID
    def servers_reconnect(id:, old_id:)
      info!(event: "servers:reconnect", id: id, old_id: old_id)

      server = ESM::Server.where(id: id).first
      return if server.nil?
      return if old_id.blank?

      # Grab the old server connection
      connection = ESM::Websocket.connection(old_id)
      return if connection.nil?

      # Disconnect the old server. The DLL will automatically reconnect in 30 seconds
      # ESM::Websocket.remove_connection(connection)
      connection.connection.close(1000, "Server ID changed, reconnecting")
    end

    #
    # Gets a channel by its ID. The bot must have send access to this channel
    #
    # @param id [String] The discord channel ID
    # @param community_id [String] Restricts the search to this community's guild
    # @param user_id [String] Requires the channel to be readable by this user's discord member
    def channel(id:, **filters)
      info!(event: "channel", id:, filters:)

      channel = ESM.bot.channel(id)
      return if channel.nil?
      return unless ESM.bot.channel_permission?(:send_messages, channel)

      if (community_id = filters[:community_id])
        community = ESM::Community.find_by(id: community_id)
        return if community.nil?
        return unless channel.server.id.to_s == community.guild_id
      end

      if (user_id = filters[:user_id])
        user = ESM::User.find_by(id: user_id)
        return if user.nil?
        return unless user.channel_permission?(:read_messages, channel)
      end

      channel.to_h
    end

    # Sends a message to a channel
    # id => ID of the channel to send
    # message => The message to send encoded as JSON
    def channel_send(id:, message:)
      info!(event: "channel:send", id: id, message: message)

      channel = ESM.bot.channel(id) || ESM.bot.user(id)
      channel = channel.pm if channel.is_a?(Discordrb::User)
      return if channel.nil?
      return if channel.text? && !ESM.bot.channel_permission?(:send_messages, channel)

      message = message.to_h || message
      if message.is_a?(Hash)
        message =
          ESM::Embed.build do |e|
            e.set_author(name: message.dig(:author, :name), icon_url: message.dig(:author, :icon_url)) if message[:author].present?

            e.title = message[:title] if message[:title]
            e.description = message[:description] if message[:description]
            e.color = message[:color] if message[:color]

            message[:fields]&.each do |field|
              e.add_field(name: field[:name], value: field[:value], inline: field[:inline] || false)
            end
          end
      end

      ESM.bot.deliver(message, to: channel)
    end

    #
    # Gets all channels for a community
    #
    # @param id [String] The database ID for the community
    # @param user_id [String] The database ID for a user to check if they have read permissions
    #
    def community_channels(id:, user_id:)
      info!(event: "community:channels", id: id, user_id: user_id)

      community = ESM::Community.find_by(id: id)
      return if community.nil?

      server = community.discord_server

      user = ESM::User.find_by(id: user_id)

      # Get the channels the bot (and user if applicable) has access to
      channels = server.channels.filter_map do |channel|
        bot_can_read = ESM.bot.channel_permission?(:send_messages, channel)
        user_can_read = true
        user_can_read = user.channel_permission?(:read_messages, channel) if user
        next unless bot_can_read && user_can_read

        channel.to_h
      end

      # Now, we're going to make the order matter
      channels.sort_by! { |c| c[:position] || 0 }

      # Load all of the category channels into a hash where the key is their ID and the value is an empty array
      grouped_channels = channels.filter_map do |category_channel|
        next unless category_channel[:type] == :category

        children = channels.select do |channel|
          channel[:type] == :text && channel.dig(:category, :id) == category_channel[:id]
        end

        [category_channel, children]
      end

      # Organize the channels under their categories
      not_categorized_channels = channels.select { |channel| channel[:type] == :text && channel[:category].nil? }

      # Add a no category array to the front
      grouped_channels.unshift([{name: community.community_name}, not_categorized_channels])

      # Return the results
      grouped_channels
    end

    #
    # Returns true/false if the user can modify this community
    #
    # @param id [String] The community's database ID
    # @param user_id [String] The user's database ID
    #
    def community_modifiable_by?(id:, user_id:)
      info!(event: "community:modifiable_by?", id: id, user_id: user_id)

      community = ESM::Community.find_by(id: id)
      return if community.nil? || community.discord_server.nil?

      user = ESM::User.find_by(id: user_id)
      return if user.nil?

      community.modifiable_by?(user.discord_user.on(community.discord_server))
    end

    #
    # Returns the roles for the community
    #
    # @param id [String] The community's database ID
    #
    def community_roles(id:)
      info!(event: "community:roles", id: id)

      community = ESM::Community.find_by(id: id)
      return if community.nil?

      server_roles = community.discord_server.roles
      return if server_roles.blank?

      server_roles.sort_by(&:position).reverse.filter_map do |role|
        next if role.permissions.administrator || role.name == "@everyone"

        {
          id: role.id.to_s,
          name: role.name,
          color: role.color.hex,
          disabled: false
        }
      end
    end

    #
    # Returns the users for the community
    #
    # @param id [String] The community's database ID
    #
    def community_users(id:)
      info!(event: "community:users", id: id)

      community = ESM::Community.find_by(id: id)
      return if community.nil?

      users = community.discord_server.users
      return if users.blank?

      users.map(&:to_h)
    end

    #
    # Returns an array of database IDs for the Community this user is part of
    #
    # @param id [String] The user's database ID
    # @param guild_ids [true/false] The IDs of the guilds to check permissions
    #
    def user_communities(id:, guild_ids:, check_for_perms: false)
      info!(event: "user:communities", id:, guild_ids:, check_for_perms:)

      user = ESM::User.find_by(id: id)
      return if user.nil?

      communities = ESM::Community.select(
        :id, :guild_id, :dashboard_access_role_ids, :community_name, :player_mode_enabled
      ).where(guild_id: guild_ids)
      return [] if communities.blank?

      discord_user = user.discord_user
      communities.filter_map do |community|
        server = community.discord_server
        next if server.nil?

        # Keeps the community metadata up to date
        community.update(community_name: server.name) if community.community_name != server.name

        discord_member = discord_user.on(server)
        next if discord_member.nil?
        next if check_for_perms && !community.modifiable_by?(discord_member)

        community.id
      end
    end

    #
    # Deletes a community from the DB and forces ESM to leave it
    #
    # @param id [String] The community's database ID
    # @param user_id [String] The user's database ID. Used to check if they have access
    #
    def community_delete(id:, user_id:)
      info!(event: "community:delete", id: id, user_id: user_id)

      community = ESM::Community.where(id: id).first
      return if community.nil?

      user = ESM::User.where(id: user_id).first
      return if user.nil?

      discord_server = community.discord_server
      return if !community.modifiable_by?(user.discord_user.on(discord_server))

      discord_server.leave
      community.destroy
    end
  end
end
