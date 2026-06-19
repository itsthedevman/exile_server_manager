# frozen_string_literal: true

module ESM
  module Discord
    class Bot
      #
      # The single chokepoint for every outbound Discord message. Source threads (command replies, log events, XM8
      # notifications, ...) enqueue here and a small pool of workers performs the actual sends, pausing +check_every+
      # seconds between each.
      #
      # The pause is deliberate. discordrb already rate limits, but it does so reactively: once a bucket is exhausted
      # it sleeps the sending thread (and a global limit sleeps every thread) until the window resets. When many
      # servers restart on the same 3-hour cadence, reconnect together, and flush their queued XM8 notifications at
      # once, sending flat-out drives the workers straight into those sleeps and the queue stalls - blocking everything
      # else that needs to talk to Discord. Pacing keeps the send rate under discordrb's threshold so it rarely has to
      # intervene, and routing every send through this queue keeps that blocking I/O off the source threads.
      #
      # Fire-and-forget callers enqueue and return immediately. Callers that need the sent message back pass
      # +wait: true+ and block on the returned promise.
      #
      class DeliveryOverseer
        #
        # A queued send and the optional promise a worker fulfills with the delivered message once discordrb returns.
        #
        Envelope = Data.define(:message, :delivery_channel, :embed_message, :replying_to, :promise)

        # Number of workers draining the queue. Several so a worker parked in one of discordrb's per-channel rate-limit
        # sleeps doesn't stall delivery to every other channel.
        WORKER_COUNT = 4

        # Longest a blocking caller will wait for Discord to confirm a send.
        WAIT_TIMEOUT = 2.minutes.to_i

        def initialize(check_every: ESM.config.bot_delivery_overseer.check_every)
          @queue = Queue.new
          @check_every = check_every
          @workers = Array.new(WORKER_COUNT) { spawn_worker }
        end

        #
        # Enqueues a message for delivery.
        #
        # @param message [String, ESM::Embed] the message or embed to send
        # @param delivery_channel [Discordrb::Channel] the resolved destination channel
        # @param embed_message [String] optional text attached alongside an embed
        # @param replying_to [Discordrb::Message, nil] a message to reference in the reply
        # @param wait [Boolean] when true, returns a promise the caller can block on
        #
        # @return [Concurrent::IVar, nil] a promise resolving to the sent Discordrb::Message (or nil on failure) when
        #   +wait+ is true; nil otherwise
        #
        def add(message, delivery_channel, embed_message: "", replying_to: nil, wait: false)
          promise = Concurrent::IVar.new if wait

          @queue << Envelope.new(
            message:,
            delivery_channel:,
            embed_message:,
            replying_to:,
            promise:
          )

          promise
        end

        private

        def spawn_worker
          Thread.new do
            while (envelope = @queue.pop)
              deliver(envelope)
              sleep(@check_every)
            end
          end
        end

        def deliver(envelope)
          message = ESM.discord_bot.__deliver(
            envelope.message,
            envelope.delivery_channel,
            embed_message: envelope.embed_message,
            replying_to: envelope.replying_to
          )

          envelope.promise&.set(message)
        rescue => e
          error!(e)

          envelope.promise&.set(nil)
        end
      end
    end
  end
end
