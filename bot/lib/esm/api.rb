# frozen_string_literal: true

module ESM
  class API < RedisIPC::Channel
    ERRORS = [
      NOT_FOUND = "not found",
      MISSING_PERMISSION = "missing permission"
    ].freeze

    stream "ipc::esm"
    channel "bot"

    # Accepts a request and triggers any logic that is required by the command
    event("requests:accept", params: [:id]) do
      info!(event: "requests:accept", params: params)

      request = ESM::Request.where(id: params[:id]).first
      raise NOT_FOUND if request.nil?

      # Respond to the request
      request.respond(true)
    end

    # Declines a request and triggers any logic that is required by the command
    event("requests:decline", params: [:id]) do
      info!(event: "requests:decline", params: params)

      request = ESM::Request.where(id: params[:id]).first
      raise NOT_FOUND if request.nil?

      # Respond to the request
      request.respond(false)
    end

    # Updates a server by sending it the initialization package again
    event("servers:update", params: [:id]) do
      info!(event: "servers:update", params: params)

      server = ESM::Server.where(id: params[:id]).first
      raise NOT_FOUND if server.nil?

      connection = ESM::Websocket.connection(server.server_id)
      return true if connection.nil?

      # Tell ESM to update the server with the new details
      ESM::Event::ServerInitialization.new(connection: connection, server: server, parameters: {}).update
    end

    # If a community changes their ID, their servers need to disconnect and reconnect
    # params[:id] => New ID
    # params[:old_id] => Old ID
    event("servers:reconnect", params: [:id, :old_id]) do
      info!(event: "servers:reconnect", params: params)

      server = ESM::Server.where(id: params[:id]).first
      raise NOT_FOUND if server.nil?
      raise NOT_FOUND if params[:old_id].blank?

      # Grab the old server connection
      connection = ESM::Websocket.connection(params[:old_id])
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
    event("channel", params: [:id, :community_id, :user_id]) do
      info!(event: "channel", params: params)

      channel = ESM.bot.channel(params[:id])
      raise NOT_FOUND if channel.nil?
      raise MISSING_PERMISSION unless ESM.bot.channel_permission?(:send_messages, channel)

      if params[:community_id]
        community = ESM::Community.find_by(id: params[:community_id])
        raise NOT_FOUND if community.nil?
        raise NOT_FOUND unless channel.server.id.to_s == community.guild_id
      end

      if params[:user_id]
        user = ESM::User.find_by(id: params[:user_id])
        raise NOT_FOUND if user.nil?
        raise MISSING_PERMISSION unless user.channel_permission?(:read_messages, channel)
      end

      channel.to_h
    end

    # Sends a message to a channel
    # params[:id] => ID of the channel to send
    # params[:message] => The message to send encoded as JSON
    event("channel:send", params: [:id, :message]) do
      info!(event: "channel:send", params: params)

      channel = ESM.bot.channel(params[:id]) || ESM.bot.user(params[:id])
      channel = channel.pm if channel.is_a?(Discordrb::User)
      raise NOT_FOUND if channel.nil?
      raise NOT_FOUND if channel.text? && !ESM.bot.channel_permission?(:send_messages, channel)

      message = params[:message].to_h || params[:message]
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
    event("community:channels", params: [:id, :user_id]) do
      info!(event: "community:channels", params: params)

      community = ESM::Community.find_by(id: params[:id])
      raise NOT_FOUND if community.nil?

      server = community.discord_server

      user = ESM::User.find_by(id: params[:user_id])

      # Get the channels the bot (and user if applicable) has access to
      channels = server.channels.filter_map do |channel|
        bot_can_read = ESM.bot.channel_permission?(:send_messages, channel)
        user_can_read = true
        user_can_read = user.channel_permission?(:read_messages, channel) if user
        next unless bot_can_read && user_can_read

        channel.to_h
      end

      # Now, we're going to make the order matter
      channels.sort_by! { |c| c[:position] }

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
    event("community:modifiable_by?", params: [:id, :user_id]) do
      info!(event: "community:modifiable_by?", params: params)

      community = ESM::Community.find_by(id: params[:id])
      raise NOT_FOUND if community.nil?

      user = ESM::User.find_by(id: params[:user_id])
      raise NOT_FOUND if user.nil?

      return community.modifiable_by?(user.discord_user.on(community.discord_server))
    end

    #
    # Returns the roles for the community
    #
    # @param id [String] The community's database ID
    #
    event("community:roles", params: [:id]) do
      info!(event: "community:roles", params: params)

      community = ESM::Community.find_by(id: params[:id])
      raise NOT_FOUND if community.nil?

      server_roles = community.discord_server.roles
      return if server_roles.blank?

      roles = server_roles.sort_by(&:position).reverse.filter_map do |role|
        next if role.permissions.administrator || role.name == "@everyone"

        {
          id: role.id.to_s,
          name: role.name,
          color: role.color.hex,
          disabled: false
        }
      end

      roles
    end

    #
    # Returns the users for the community
    #
    # @param id [String] The community's database ID
    #
    event("community:users", params: [:id]) do
      info!(event: "community:users", params: params)

      community = ESM::Community.find_by(id: params[:id])
      raise NOT_FOUND if community.nil?

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
    event("user:communities", params: [:id, :guild_ids]) do
      info!(event: "user:communities", params: params)

      user = ESM::User.find_by(id: params[:id])
      raise NOT_FOUND if user.nil?

      communities = ESM::Community.select(:id, :guild_id, :dashboard_access_role_ids, :community_name, :player_mode_enabled).where(guild_id: params[:guild_ids])
      return [] if communities.blank?

      discord_user = user.discord_user
      community_ids = communities.filter_map do |community|
        server = community.discord_server
        next if server.nil?

        # Keeps the community metadata up to date
        community.update(community_name: server.name) if community.community_name != server.name
        next unless community.modifiable_by?(discord_user.on(server))

        community.id
      end

      community_ids
    end

    #
    # Deletes a community from the DB and forces ESM to leave it
    #
    # @param id [String] The community's database ID
    # @param user_id [String] The user's database ID. Used to check if they have access
    #
    event("community:delete", params: [:id, :user_id]) do
      info!(event: "community:delete", params: params)

      community = ESM::Community.where(id: params[:id]).first
      raise NOT_FOUND if community.nil?

      user = ESM::User.where(id: params[:user_id]).first
      raise NOT_FOUND if user.nil?

      discord_server = community.discord_server
      raise MISSING_PERMISSION if !community.modifiable_by?(user.discord_user.on(discord_server))

      discord_server.leave
      community.destroy
    end
  end
end
