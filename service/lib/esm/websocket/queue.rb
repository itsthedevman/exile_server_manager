# frozen_string_literal: true

module ESM
  class Websocket
    class Queue < Hash
      def initialize
        @order = []
      end

      def <<(request)
        @order << request.id
        self[request.id] = request
      end

      def first
        self[@order.first]
      end

      def remove(id)
        @order.delete(id)
        delete(id)
      end
    end
  end
end
