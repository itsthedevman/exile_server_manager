# frozen_string_literal: true

module ESM
  module Connection
    class Server
      delegate :on_initialize, :on_disconnect, to: :@connection_manager

      def initialize
        @config = ESM.config.connection_server
        @connection_manager = ConnectionManager.new(@config.lobby_timeout)
        @server = ServerSocket.new(TCPServer.new("0.0.0.0", ESM.config.ports.connection_server))
      end

      def start
        execution_interval = @config.connection_check
        @task = Concurrent::TimerTask.execute(execution_interval:) { on_connect }
        @task.add_observer(ErrorHandler.new)

        info!(status: :started)
      end

      def stop
        @server&.shutdown(:RDWR)
      end

      def client(id)
        @connection_manager.find(id)
      end

      private

      def on_connect
        socket = @server.accept
        return unless socket.is_a?(TCPSocket)

        @connection_manager.on_connect(socket)
      end
    end
  end
end
