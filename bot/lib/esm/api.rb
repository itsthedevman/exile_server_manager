# frozen_string_literal: true

module ESM
  class API < Sinatra::Base
    def self.run!
      Thread.new {
        super
        quit!
      }
    end

    # Sinatra hooks the Ctrl-C event.
    # This method is now in charge of killing everything. yaay /s
    def self.quit!
      super

      # Stop the bot
      ESM.bot.stop
    end

    ######################################
    set(:port, ENV["API_PORT"])

    # Every request must be authorized
    before do
      halt(401) if request.env["HTTP_AUTHORIZATION"] != "Bearer #{ENV["API_AUTH_KEY"]}"
    end

    # Accepts a request and triggers any logic that is required by the command
    put("/requests/:id/accept") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      request = ESM::Request.where(id: params[:id]).first
      return halt(404) if request.nil?

      # Respond to the request
      request.respond(true)
    end

    # Declines a request and triggers any logic that is required by the command
    put("/requests/:id/decline") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      request = ESM::Request.where(id: params[:id]).first
      return halt(404) if request.nil?

      # Respond to the request
      request.respond(false)
    end

    # Updates a server by sending it the initialization package again
    put("/servers/:id/update") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      server = ESM::Server.where(id: params[:id]).first
      return halt(404) if server.nil?

      connection = ESM::Websocket.connection(server.server_id)
      return halt(200) if connection.nil?

      # Tell ESM to update the server with the new details
      ESM::Event::ServerInitialization.new(connection: connection, server: server, parameters: {}).update
    end

    # If a community changes their ID, their servers need to disconnect and reconnect
    # params[:id] => New ID
    # params[:old_id] => Old ID
    put("/servers/:id/reconnect") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      server = ESM::Server.where(id: params[:id]).first
      return halt(404) if server.nil?
      return halt(404) if params[:old_id].blank?

      # Grab the old server connection
      connection = ESM::Websocket.connection(params[:old_id])
      return halt(200) if connection.nil?

      # Disconnect the old server. The DLL will automatically reconnect in 30 seconds
      # ESM::Websocket.remove_connection(connection)
      connection.connection.close(1000, "Server ID changed, reconnecting")
    end

    # If a community changes their prefix, update the bot
    # params[:id] => ID of community
    put("/community/:id/update_command_prefix") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      community = ESM::Community.where(id: params[:id]).first
      return halt(404) if community.nil?

      # Update the prefix for this community
      ESM.bot.update_prefix(community)
    end

    #
    # Gets a channel by its ID. The bot must have send access to this channel
    #
    # @param id [String] The discord channel ID
    # @param community_id [String] Restricts the search to this community's guild
    # @param user_id [String] Requires the channel to be readable by this user's discord member
    get("/channel/:id") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      channel = ESM.bot.channel(params[:id])
      return halt(404) if channel.nil?
      return halt(422) unless ESM.bot.channel_permission?(:send_messages, channel)

      if params[:community_id]
        community = ESM::Community.find_by_id(params[:community_id])
        return halt(404) if community.nil?
        return halt(422) unless channel.server.id.to_s == community.guild_id
      end

      if params[:user_id]
        user = ESM::User.find_by_id(params[:user_id])
        return halt(404) if user.nil?
        return halt(422) unless user.channel_permission?(:read_messages, channel)
      end

      ESM.logger.info("#{self.class}##{__method__}") { "END" }

      channel.to_h.to_json
    end

    # Sends a message to a channel
    # params[:id] => ID of the channel to send
    # params[:message] => The message to send encoded as JSON
    post("/channel/:id/send") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      channel = ESM.bot.channel(params[:id])
      return halt(404) if channel.nil?
      return halt(404) unless ESM.bot.channel_permission?(:send_messages, channel)

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

      ESM.logger.info("#{self.class}##{__method__}") { "END" }
      ESM.bot.deliver(message, to: channel)
    end

    #
    # Gets all channels for a community
    #
    # @param id [String] The database ID for the community
    # @param user_id [String] The database ID for a user to check if they have read permissions
    #
    get("/community/:id/channels") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      community = ESM::Community.find_by_id(params[:id])
      return halt(404) if community.nil?

      server = community.discord_server

      user = ESM::User.find_by_id(params[:user_id])

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

      ESM.logger.info("#{self.class}##{__method__}") { "END - #{channels.size}" }

      # Return the results
      grouped_channels.to_json
    end

    #
    # Returns true/false if the user can modify this community
    #
    # @param id [String] The community's database ID
    # @param user_id [String] The user's database ID
    #
    # @return [true/false]
    #
    get("/community/:id/is_modifiable_by/:user_id") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      community = ESM::Community.find_by_id(params[:id])
      return halt(404) if community.nil?

      user = ESM::User.find_by_id(params[:user_id])
      return halt(404) if user.nil?

      result = community.modifiable_by?(user.discord_user.on(community.discord_server))
      ESM.logger.info("#{self.class}##{__method__}") { "END - #{result}" }
      result.to_s
    end

    #
    # Returns the roles for the community
    #
    # @param id [String] The community's database ID
    #
    get("/community/:id/roles") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      community = ESM::Community.find_by_id(params[:id])
      return halt(404) if community.nil?

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

      ESM.logger.info("#{self.class}##{__method__}") { "END - #{roles.size}" }
      roles.to_json
    end

    #
    # Returns the users for the community
    #
    # @param id [String] The community's database ID
    #
    get("/community/:id/users") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      community = ESM::Community.find_by_id(params[:id])
      return halt(404) if community.nil?

      users = community.discord_server.users
      return if users.blank?

      ESM.logger.info("#{self.class}##{__method__}") { "END - #{users.size}" }
      users.map(&:to_h).to_json
    end

    #
    # Returns an array of database IDs for the Community this user is part of
    #
    # @param id [String] The user's database ID
    # @param player_mode_enabled [true/false] True: Filters the communities to only include player mode communities
    #                                         False: Filters the communities based on if the user is an admin or has access to modify
    #
    get("/user/:id/communities") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      user = ESM::User.find_by_id(params[:id])
      return halt(404) if user.nil?

      communities = ESM::Community.select(:id, :guild_id, :dashboard_access_role_ids, :community_name, :player_mode_enabled).where(guild_id: params[:guild_ids])
      return "[]" if communities.blank?

      discord_user = user.discord_user
      community_ids = communities.filter_map do |community|
        server = community.discord_server
        next if server.nil?

        # Keeps the community metadata up to date
        community.update(community_name: server.name) if community.community_name != server.name
        next unless community.modifiable_by?(discord_user.on(server))

        community.id
      end

      ESM.logger.info("#{self.class}##{__method__}") { "END - #{community_ids.size}" }
      community_ids.to_json
    end
  end
end
