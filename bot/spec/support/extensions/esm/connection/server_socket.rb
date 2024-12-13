# frozen_string_literal: true

module ESM
  module Connection
    class ServerSocket < Socket
      def blocker
        @blocker ||= Concurrent::AtomicBoolean.new
      end

      def block!
        blocker.make_true
      end

      def unblock!
        blocker.make_false
      end

      alias_method :og_readable?, :readable?

      def readable?
        return if blocker.true?

        og_readable?
      end
    end
  end
end
