# frozen_string_literal: true

module ESM
  class Bot
    class ResendQueue
      def initialize(bot)
        @bot = bot
        @entries = []
        @max_attempts = ESM.config.loops.bot_resend_queue.max_attempts

        @thread = Thread.new do
          check_every = ESM.config.loops.bot_resend_queue.check_every

          loop do
            next if @pause

            process_queue
            sleep(ESM.env.test? ? 0.5 : check_every)
          end
        end
      end

      def die
        return if @thread.nil?

        Thread.kill(@thread)
      end

      def enqueue(message, to:, exception:)
        return if enqueued?(message, to: to)

        @entries << OpenStruct.new(
          message: message,
          to: to,
          exception: exception,
          attempt: 1
        )
      end

      def dequeue(message, to:)
        return if !enqueued?(message, to: to)

        index = @entries.index { |obj| obj.message == message && obj.to == to }
        @entries.delete_at(index)
      end

      def enqueued?(message, to:)
        @entries.any? { |obj| obj.message == message && obj.to == to }
      end

      def size
        @entries.size
      end

      if ESM.env.test?
        attr_accessor :entries

        def reset
          @entries = []
        end

        def pause
          @pause = true
        end

        def resume
          @pause = false
        end
      end

      private

      def process_queue
        @entries.each_with_index do |entry, index|
          if entry.attempt >= @max_attempts
            ESM::Notifications.trigger("bot_resend_queue", message: entry.message, to: entry.to, exception: entry.exception)

            @entries.delete_at(index)
          else
            # Increment the counter
            entry.attempt += 1

            # Attempt another delivery
            @bot.deliver(entry.message, to: entry.to)
          end
        end
      end
    end
  end
end
