# frozen_string_literal: true

module ESM
  class API < Sinatra::Base
    def self.run!
      Thread.new { super; quit! }
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
  end
end
