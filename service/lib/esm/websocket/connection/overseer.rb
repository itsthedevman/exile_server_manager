# frozen_string_literal: true

module ESM
  class Websocket
    module Connection
      class Overseer
        def initialize
          @queue = []
          @mutex = Mutex.new

          oversee!
        end

        def add_to_lobby(connection)
          @queue << connection
        end

        private

        def oversee!
          check_every = ESM.config.websocket_connection_overseer.check_every

          @watch_thread = Thread.new do
            loop do
              sleep(check_every)

              connection = @mutex.synchronize { @queue.pop }
              next if connection.nil?

              ESM::Websocket.new(connection)
            end
          end
        end
      end
    end
  end
end
