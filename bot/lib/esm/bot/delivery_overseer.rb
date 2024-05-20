# frozen_string_literal: true

module ESM
  class Bot
    class DeliveryOverseer
      class Envelope < ImmutableStruct.define(:id, :message, :delivery_channel, :embed_message, :replying_to, :wait)
        def initialize(**args)
          defaults = {id: nil, wait: false}

          if args[:wait]
            defaults[:id] = SecureRandom.uuid
            defaults[:wait] = true
          end

          super(**defaults.merge(args))
        end
      end

      class PendingDelivery < ImmutableStruct.define(:id)
        SLEEP = 0.2 # Seconds
        TIMEOUT = 2.minutes.to_i / SLEEP

        def wait_for_delivery
          counter = 0

          while counter < TIMEOUT
            sleep(SLEEP)
            return retrieve_message if ESM.redis.exists?(id)

            counter += 1
          end
        end

        def retrieve_message
          ESM.bot.delivery_overseer.get(id)
        end
      end

      class Delivery < ImmutableStruct.define(:id, :message, :timeout)
        def initialize(id:, message:, timeout: 2.minutes)
          super(id: id, message: message, timeout: timeout.from_now)
        end

        def timed_out?
          timeout < ::Time.current
        end

        def delivered
          ESM.redis.set(id, "1", ex: timeout.to_i)
        end
      end

      def initialize
        @queue = Queue.new
        @deliveries = {}
        @deliveries_mutex = Mutex.new
        @check_every = ESM.config.bot_delivery_overseer.check_every.freeze

        @deliveries_thread = oversee_deliveries!
        @sender_thread_one = oversee!
        @sender_thread_two = oversee!
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
        return PendingDelivery.new(envelope.id) if wait

        nil
      end

      def get(id)
        @deliveries_mutex.synchronize do
          delivery = @deliveries.delete(id)
          delivery&.message
        end
      end

      private

      def oversee!
        Thread.new do
          sleep(rand(@check_every))

          loop do
            sleep(@check_every + rand(@check_every))

            envelope = @queue.pop(timeout: 0)
            next if envelope.nil?

            message = ESM.bot.__deliver(
              envelope.message,
              envelope.delivery_channel,
              embed_message: envelope.embed_message,
              replying_to: envelope.replying_to
            )

            next unless envelope.wait

            @deliveries_mutex.synchronize do
              delivery = Delivery.new(envelope.id, message)
              @deliveries[envelope.id] = delivery
              delivery.delivered
            end
          rescue => e
            error!(e)
          end
        end
      end

      def oversee_deliveries!
        Thread.new do
          loop do
            sleep(20.seconds)

            # Clear any timed out messages
            @deliveries_mutex.synchronize do
              @deliveries.delete_if { |_id, delivery| delivery.timed_out? }
            end
          end
        end
      end
    end
  end
end
