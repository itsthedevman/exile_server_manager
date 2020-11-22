# frozen_string_literal: true

module ESM
  class Websocket
    class << self
      attr_reader :connections, :server_ids
    end

    ###########################
    # Public Class Methods
    ###########################

    # Starts the websocket server and the request watcher thread
    def self.start!
      @connections = {}
      @server_ids = ESM::Server.all.pluck(:server_id)

      # Start the websocket server
      ESM::Websocket::Server.run

      # Watches over requests and removes them if the server is taking too long to respond
      ESM::Websocket::Request::Overseer.watch!
    end

    # Delivers the message to the requested server_id
    #
    # @note Do not rescue. This will fall down to the calling class
    def self.deliver!(server_id, request)
      connection = @connections[server_id]
      request.command.check_failed!(:server_not_connected, user: request.user.mention, server_id: server_id) if connection.nil?
      request.command.check_failed!(:server_not_initialized, user: request.user.mention, server_id: server_id) if !connection.ready?

      connection.deliver!(request)
    end

    # Adds a new connection to the connections
    def self.add_connection(connection)
      # Uniquely append to the server IDs array
      @server_ids |= [connection.server.server_id]
      @connections[connection.server.server_id] = connection
    end

    # Removes a connection from the connections
    def self.remove_connection(connection)
      connection.server.update(disconnected_at: ::Time.now) if !ESM.env.test?
      @server_ids.delete(connection.server.server_id)
      @connections.delete(connection.server.server_id)
    end

    # Removes all connections
    def self.remove_all_connections!
      @connections.each { |_server_id, connection| self.remove_connection(connection) }
    end

    # Checks to see if there are any corrections and provides them for the server id
    def self.correct(server_id)
      checker = DidYouMean::SpellChecker.new(dictionary: @server_ids)
      checker.correct(server_id)
    end

    def self.connected?(server_id)
      !@connections[server_id].nil?
    end

    # Retrieves the WS connection based on a server_id
    #
    # @param server_id [String] The ESM set ID, not the DB ID
    # @returns [WebsocketConnection, nil]
    def self.connection(server_id)
      @connections[server_id]
    end

    ###########################
    # Public Instance Methods
    ###########################
    attr_reader :server, :connection, :requests

    attr_writer :requests if ESM.env.test?

    def initialize(connection)
      @ready = false
      @connection = connection
      @requests = ESM::Websocket::Queue.new
      bind_events

      on_open
    end

    def deliver!(request)
      ESM::Notifications.trigger("websocket_server_deliver", request: request)

      # If the user is nil, there is no point in tracking the request
      @requests << request if !request.user.nil?

      # Send the message
      @connection.send(request.to_s)

      request
    end

    # Removes a request via its commandID
    # @returns [ESM::Websocket::Request, nil]
    def remove_request(command_id)
      @requests.remove(command_id)
    end

    # Returns if the server has been sent the post_init package
    # @return boolean
    def ready?
      @ready
    end

    # Sets if the server has been sent the post_init package
    def ready=(boolean)
      @ready = boolean
    end

    ###########################
    # Private Instance Methods
    ###########################
    private

    # @private
    # Authorizes the request from the DLL based on its server key
    def authorize!
      # authorization header is "basic BASE_64_STRING"
      authorization = @connection.env["HTTP_AUTHORIZATION"][6..-1]

      raise ESM::Exception::FailedAuthentication, "Missing authorization key" if authorization.blank?

      # Once decoded, it becomes "arma_server:esm_key"
      key = Base64.strict_decode64(authorization)[12..-1].strip

      @server = ESM::Server.where(server_key: key).first
      raise ESM::Exception::FailedAuthentication, "Invalid Key" if @server.nil?

      # If the bot is no longer a member of the server, don't allow it to connect
      discord_server = @server.community.discord_server
      raise ESM::Exception::FailedAuthentication, "Unable to find Discord Server" if discord_server.nil?

      # If the server is already connected, don't allow it to connect again
      raise ESM::Exception::FailedAuthentication, "This server is already connected" if ESM::Websocket.connected?(@server.server_id)
    end

    # @private
    def bind_events
      @connection.on(:close, &method(:on_close))
      @connection.on(:message, &method(:on_message))
      @connection.on(:pong, &method(:on_pong))
      @connection.on(:error, &method(:on_error))
    end

    # @private
    # Websocket event, executes when a A3 server connects
    def on_open
      # Authorize the request and extract the server key
      authorize!

      # Tell the server to store the connection for access later
      ESM::Websocket.add_connection(self)
    rescue ESM::Exception::FailedAuthentication => e
      # Application code may only use codes from 1000, 3000-4999
      @connection.close(1002, e.message)
    rescue StandardError => e
      ESM.logger.fatal("#{self.class}##{__method__}") { "Message:\n#{e.message}\n\nBacktrace:\n#{e.backtrace}" }
    end

    # @private
    # Websocket event, executes when a A3 server sends a message
    def on_message(event)
      # Messages with commandID are requests from the Bot
      # Messages without are DLL generated requests
      message = event.data.to_ostruct

      # These are normally empty responses
      # message.returned is legacy
      return if message.ignore || message.returned

      # Reload the server so our data is fresh
      @server.reload

      # Process the request
      Thread.new { ESM::Websocket::ServerRequest.new(connection: self, message: message).process }
    rescue StandardError => e
      ESM.logger.error("#{self.class}##{__method__}") { "Exception: #{e.message}\n#{e.backtrace[0..5].join("\n")}" }
      raise e if ESM.env.test?
    end

    # @private
    # Websocket event, executes when a A3 server or the WebServer disconnects the connection
    def on_close(_code)
      return if @server.nil?

      ESM::Notifications.trigger("websocket_server_on_close", server: @server)

      ESM::Websocket.remove_connection(self)
    end

    # @private
    # Websocket event, executes when the A3 server replies to a pong? IDK yet, untested.
    def on_pong(message)
      puts "[WS on_pong] #{message}"
    end

    def on_error(event)
      ESM.logger.debug("#{self.class}##{__method__}") { "#{@server.server_id} | ON ERROR\nMessage: #{event.message}" }
    end
  end
end
