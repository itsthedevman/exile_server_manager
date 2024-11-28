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
      connection.server.update(disconnected_at: ::Time.zone.now) if !ESM.env.test?
      @server_ids.delete(connection.server.server_id)
      @connections.delete(connection.server.server_id)
    end

    # Removes all connections
    def self.remove_all_connections!
      @connections.each { |_server_id, connection| remove_connection(connection) }
    end

    def self.connected?(server_id)
      connection(server_id).present?
    end

    # Retrieves the WS connection based on a server_id
    #
    # @param server_id [String] The ESM set ID, not the DB ID
    # @return [WebsocketConnection, nil]
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
      @closed = false

      # In dev, for whatever reason, this ping causes all messages to be delayed 15 seconds.
      @ping_timer = EventMachine.add_periodic_timer(10) { ping } if ESM.env.production?

      on_open
    end

    def deliver!(request)
      info!(request.to_h)

      @requests << request

      # Send the message
      @connection.send(request.to_s)

      request
    end

    # Removes a request via its commandID
    # @return [ESM::Websocket::Request, nil]
    def remove_request(command_id)
      @requests.remove(command_id)
    end

    # Returns if the server has been sent the post_init package
    # @return boolean
    def ready?
      @ready
    end

    # Sets if the server has been sent the post_init package
    attr_writer :ready

    # Sends a ping to the WS client.
    def ping
      @connection.ping
    end

    ###########################
    # Private Instance Methods
    ###########################
    private

    # @private
    # Authorizes the request from the DLL based on its server key
    def authorize!
      # authorization header is "basic BASE_64_STRING"
      authorization = @connection.env["HTTP_AUTHORIZATION"][6..]

      raise ESM::Exception::FailedAuthentication, "Missing authorization key" if authorization.blank?

      # Once decoded, it becomes "arma_server:esm_key"
      key = Base64.strict_decode64(authorization)[12..].strip

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

      bind_events

      # Tell the server to store the connection for access later
      ESM::Websocket.add_connection(self)
    rescue ESM::Exception::FailedAuthentication => e
      # Application code may only use codes from 1000, 3000-4999
      @connection.close(3002, e.message)
    rescue => e
      @connection.close(3002, e.message)
      ESM.logger.fatal("#{self.class}##{__method__}") { "Message:\n#{e.message}\n\nBacktrace:\n#{e.backtrace}" }
    end

    # @private
    # Websocket event, executes when a A3 server sends a message
    def on_message(event)
      # Messages with commandID are requests from the Bot
      # Messages without are DLL generated requests
      server_request = ESM::Websocket::ServerRequest.new(connection: self, message: event.data.to_ostruct)

      # Checks if the request should be processed
      if server_request.invalid?
        server_request.remove_request if server_request.remove_on_ignore?
        return
      end

      # Reload the server so our data is fresh
      @server.reload

      # Process the request
      Thread.new do
        ESM::Database.with_connection do
          server_request.process
        end
      rescue => e
        ESM.logger.error("#{self.class}##{__method__}") { "Exception: #{e.message}\n#{e.backtrace[0..5].join("\n")}" }
        raise e if ESM.env.test?
      end
    rescue => e
      ESM.logger.error("#{self.class}##{__method__}") { "Exception: #{e.message}\n#{e.backtrace[0..5].join("\n")}" }
      raise e if ESM.env.test?
    end

    # @private
    # Websocket event, executes when a A3 server or the WebServer disconnects the connection
    def on_close(_code)
      return if @server.nil?
      return if @closed

      EventMachine.cancel_timer(@ping_timer) if @ping_timer

      info!(bot_stopping: ESM.bot.stopping?, server_id: @server.server_id, uptime: @server.uptime)

      message =
        if ESM.bot.stopping?
          I18n.t("server_disconnected_esm_stopping", server: @server.server_id, uptime: @server.uptime)
        else
          I18n.t("server_disconnected", server: @server.server_id, uptime: @server.uptime)
        end

      @server.community&.log_event(:reconnect, message)

      ESM::Websocket.remove_connection(self)
      @closed = true
    end

    # @private
    # Websocket event, executes when the A3 server replies to a pong? IDK yet, untested.
    def on_pong(message)
      Rails.logger.debug "[WS on_pong] #{message}"
    end

    def on_error(event)
      ESM.logger.debug("#{self.class}##{__method__}") { "#{@server.server_id} | ON ERROR\nMessage: #{event.message}" }
    end
  end
end
