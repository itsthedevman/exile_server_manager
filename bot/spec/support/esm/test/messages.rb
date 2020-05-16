# frozen_string_literal: true

module ESM
  class Test
    class Messages < Array
      def store(message, to, channel)
        # Don't break tests
        self << [channel, message]

        # Remove the message set from the queue
        ESM.bot.resend_queue.dequeue(message, to: to)
      end
    end
  end
end
