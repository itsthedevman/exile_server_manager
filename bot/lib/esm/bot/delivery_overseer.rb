# frozen_string_literal: true

module ESM
  class Bot
    class DeliveryOverseer
      Envelope = ImmutableStruct.define(:message, :delivery_channel, :embed_message, :replying_to)

      def initialize
        @queue = Queue.new
        oversee!
      end

      def add(message, delivery_channel, embed_message: "", replying_to: nil)
        @queue << Envelope.new(message, delivery_channel, embed_message, replying_to)
      end

      private

      def oversee!
        check_every = ESM.config.loops.bot_delivery_overseer.check_every

        @watch_thread = Thread.new do
          loop do
            sleep(check_every)

            envelope = @queue.pop
            next if envelope.nil?

            ESM.bot.__deliver(
              envelope.message,
              envelope.delivery_channel,
              embed_message: envelope.embed_message,
              replying_to: envelope.replying_to
            )
          end
        end
      end
    end
  end
end
