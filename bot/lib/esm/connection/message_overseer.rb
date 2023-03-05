# frozen_string_literal: true

module ESM
  class Connection
    class MessageOverseer
      Envelope = Struct.new(:message, :expires_at) do
        delegate :delivered?, to: :message

        def undeliverable?
          expires_at <= ::Time.now
        end
      end

      attr_reader :mailbox if ESM.env.test?

      def initialize
        @mailbox = {}

        check_every = ESM.config.loops.connection_message_overseer.check_every
        @thread = Thread.new do
          loop do
            check_messages
            sleep(ESM.env.test? ? 0.5 : check_every)
          end
        end
      end

      def size
        @mailbox.size
      end

      #
      # Watches a message for a delivery response. If the message never receives one, the message's `on_error` callback will be triggered
      #
      # @param message [ESM::Message] The message to match
      # @param expires_at [DateTime, Time] The time when the message should be considered undeliverable.
      #
      def watch(message, expires_at: 10.seconds.from_now)
        envelope = Envelope.new(message, expires_at)
        @mailbox[message.id] = envelope
      end

      #
      # Find and return a message based on its ID
      #
      # @param id [String] The ID of the message
      #
      # @return [ESM::Message, Nil] The message or nil
      #
      def retrieve(id)
        envelope = remove(id)
        return if envelope.nil?

        envelope.message
      end

      def remove(id)
        @mailbox.delete(id)
      end

      def remove_all!(with_error: false)
        @mailbox.each do |id, envelope|
          message = envelope.message

          if with_error
            message.add_error("code", "message_undeliverable")
            message.on_error(nil)
          end

          remove(id)
        end
      end

      private

      def check_messages
        # Hey look, I'm the government
        @mailbox.each do |id, envelope|
          next if !envelope.undeliverable?

          # Don't skip - The envelope needs to be removed
          if !envelope.delivered?
            message = envelope.message
            message.add_error("code", "message_undeliverable")
            message.on_error(nil)
          end

          remove(id)
        rescue => e
          error!(error: e)
          remove(id)
        end
      end
    end
  end
end
