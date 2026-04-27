# frozen_string_literal: true

module ESM
  module Connection
    class Ledger < Concurrent::Map
      def include?(request)
        !self[request.id].nil?
      end

      def add(request)
        self[request.id] = Promise.new
      end

      def remove(request)
        delete(request.id)
      end
    end
  end
end
