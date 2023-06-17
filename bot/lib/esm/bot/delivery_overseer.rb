# frozen_string_literal: true

module ESM
  class Bot
    class DeliveryOverseer
      TIMEOUT = 5 # seconds

      Envelope = ImmutableStruct.define(
        :id, :message, :delivery_channel, :embed_message, :replying_to, :wait
      ) do
        def initialize(**args)
          defaults = {id: nil, wait: false}

          defaults.merge!(id: SecureRandom.uuid, wait: true) if args[:wait]
          super(**defaults.merge(args))
        end
      end

      def initialize
        @deliveries = {}
        @mutex = Mutex.new
        @queue = Queue.new
        @check_every = ESM.config.loops.bot_delivery_overseer.check_every.freeze

        oversee!
      end

      def add(message, delivery_channel, embed_message: "", replying_to: nil, wait: false)
        envelope = Envelope.new(
          message: message,
          delivery_channel: delivery_channel,
          embed_message: embed_message,
          replying_to: replying_to,
          wait: wait
        )

        @queue << envelope
        return envelope.id if wait

        nil
      end

      def wait_for_delivery(id)
        counter = 0

        loop do
          sleep(@check_every)

          counter += 1
          result = @mutex.synchronize { @deliveries.delete(id) }

          return result&.first if result || counter > TIMEOUT
        end

        nil
      end

      private

      def oversee!
        @watch_thread = Thread.new do
          loop do
            sleep(@check_every)

            # Ensure the @deliveries does not become a memory leak
            @mutex.synchronize do
              @deliveries.delete_if { |(_, timeout)| timeout < Time.now }
            end

            envelope = @queue.pop
            next if envelope.nil?

            message = ESM.bot.__deliver(
              envelope.message,
              envelope.delivery_channel,
              embed_message: envelope.embed_message,
              replying_to: envelope.replying_to
            )

            next unless envelope.wait

            @mutex.synchronize do
              @deliveries[envelope.id] = [message, TIMEOUT.seconds.from_now]
            end
          end
        end
      end
    end
  end
end
