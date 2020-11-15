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

    # Sinatra server configuration below
    set(:port, ENV["API_PORT"])

    before do
      halt(401) if request.env["HTTP_AUTHORIZATION"] != "Bearer #{ENV["API_AUTH_KEY"]}"
    end

    put("/requests/:id/accept") do
      ESM.logger.debug("#{self.class}##{__method__}") { params }

      request = ESM::Request.where(id: params[:id]).first
      return halt(404) if request.nil?

      # Respond to the request
      request.respond(true)
    end

    put("/requests/:id/decline") do
      ESM.logger.debug("#{self.class}##{__method__}") { params }

      request = ESM::Request.where(id: params[:id]).first
      return halt(404) if request.nil?

      # Respond to the request
      request.respond(false)
    end

    put("/servers/:id/reconnect") do
      ESM.logger.debug("#{self.class}##{__method__}") { params }

      server = ESM::Server.where(id: params[:id]).first
      return halt(404) if server.nil?

      connection = ESM::Websocket.connection(server.server_id)
      return halt(200) if connection.nil?

      # Tell ESM to update the server with the new details
      ESM::Event::ServerInitialization.new(connection: connection, server: server, parameters: {}).update
    end
  end
end
