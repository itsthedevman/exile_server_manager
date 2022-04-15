# frozen_string_literal: true

module ESM
  class Test
    class Messages < Array
      # By default, ESM returns `nil` from #deliver if the message fails to send.
      attr_accessor :simulate_message_failure

      def store(message, channel)
        # Don't break tests
        self << [channel, message]

        message unless simulate_message_failure
      end
    end
  end
end
