# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def disconnect_all
        @lobby.each(&:close)
        @connections.each_value(&:close)

        @lobby.clear
        @connections.clear
      end
    end
  end
end
