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

    # Sends a message to a channel
    # params[:id] => ID of the channel to send
    # params[:message] => The message to send encoded as JSON
    post("/channel/:id/send") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      channel = ESM.bot.channel(params[:id])
      return halt(404) if channel.nil?

      message = ESM::JSON.parse(params[:message])
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

    get("/community/:id/channels") do
      ESM.logger.info("#{self.class}##{__method__}") { params }

      community = ESM::Community.find_by_guild_id(params[:id])
      return halt(404) if community.nil?

      server = community.discord_server
      bot_member = ESM.bot.profile.on(server)
      return halt(404) if bot_member.nil?

      # Get the channels the bot has access to
      channels = server.channels.select do |channel|
        bot_member.permission?(:send_messages, channel)
      end

      # Now, we're going to make the order matter
      channels.sort_by!(&:position)

      # Load all of the category channels into a hash where the key is their ID and the value is an empty array
      grouped_channels = channels.select(&:category?).map do |category_channel|
        [
          category_channel.to_h,
          category_channel.text_channels.sort_by(&:position).map(&:to_h)
        ]
      end

      # Organize the channels under their categories
      not_categorized_channels = channels.select { |channel| channel.text? && channel.category.nil? }
        .sort_by(&:position)
        .map(&:to_h)

      # Add a no category array to the front
      grouped_channels.unshift([{name: community.community_name}, not_categorized_channels])

      # Return the results
      grouped_channels.to_json
    end
  end
end
