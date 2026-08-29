# frozen_string_literal: true

module ESM
  module Arma
    class Server
      include Singleton

      class << self
        delegate :start, :stop, :client, :on_initialize, :on_disconnect, to: :instance
      end

      delegate :on_initialize, :on_disconnect, to: :@connection_manager

      def initialize
        @server = ServerSocket.new(
          TCPServer.new("0.0.0.0", ESM.config.ports.connection_server)
        )

        @config = ESM.config.connection_server

        @connection_manager = ConnectionManager.new(
          lobby_timeout: @config.lobby_timeout,
          heartbeat_timeout: @config.heartbeat_timeout
        )
      end

      def start
        execution_interval = @config.connection_check

        @task = TimerTask.execute(execution_interval:) { on_connect }

        info!(status: :started, port: ESM.config.ports.connection_server)
      end

      def stop
        info!(status: :stopping)
        @connection_manager.stop

        @server.close
        @task&.shutdown

        info!(status: :stopped)
      end

      def client(id)
        @connection_manager.find(id)
      end

      private

      def on_connect
        socket = @server.accept
        return unless socket.is_a?(TCPSocket)

        _family, port, _hostname, address = socket.peeraddr(false)

        info!(
          state: :accepted,
          peer: "#{address}:#{port}"
        )

        @connection_manager.on_connect(socket)
      end
    end
  end
end
