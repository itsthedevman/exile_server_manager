# frozen_string_literal: true

module ESM
  module Connection
    class Promise
      def initialize
        @inner = Concurrent::MVar.new
        @promise = Concurrent::Promise.new
      end

      def set_response(response)
        @inner.put(response)
        true
      end

      def then(&)
        @promise = @promise.then(&)
        self
      end

      delegate :execute, :state, to: :@promise

      def wait_for_response(timeout = 0)
        self.then do |_|
          case (result = @inner.take(timeout))
          when Request
            Response.fulfilled(result.content)
          when StandardError
            Response.rejected(result)
          else
            # Concurrent::MVar::TIMEOUT
            Response.rejected(ESM::Exception::RequestTimeout.new)
          end
        end

        execute if @promise.state == :unscheduled
        @promise = @promise.wait

        if @promise.fulfilled?
          @promise.value
        else
          Response.rejected(@promise.reason)
        end
      end
    end
  end
end
