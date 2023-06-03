# frozen_string_literal: true

module ESM
  module Connection
    class MessageOverseer
      Envelope = Struct.new(:message, :expires_at) do
        delegate :delivered?, to: :message

        def expired?
          expires_at <= ::Time.now
        end
      end

      def initialize
        @mailbox = {}
        @mutex = Mutex.new

        check_every = ESM.config.loops.connection_message_overseer.check_every
        @thread = Thread.new do
          loop do
            check_messages
            sleep(check_every)
          end
        end
      end

      def size
        @mutex.synchronize { @mailbox.size }
      end

      #
      # Watches a message for a delivery response. If the message never receives one, the message's `on_error` callback will be triggered
      #
      # @param message [ESM::Message] The message to match
      # @param expires_at [DateTime, Time] The time when the message should be considered undeliverable.
      #
      def watch(message, expires_at: 10.seconds.from_now)
        envelope = Envelope.new(message, expires_at)
        @mutex.synchronize { @mailbox[message.id] = envelope }
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
        @mutex.synchronize { @mailbox.delete(id) }
      end

      def remove_all!(with_error: false)
        @mutex.synchronize do
          @mailbox.each do |id, envelope|
            @mailbox.delete(id)
            next unless with_error

            message = envelope.message
            message.add_error("code", "message_undeliverable")
            message.on_error(nil)
          rescue => e
            error!(error: e)
          end
        end
      end

      private

      def check_messages
        messages = []

        @mutex.synchronize do
          # Hey look, I'm the government
          @mailbox.each do |id, envelope|
            next unless envelope.expired?

            @mailbox.delete(id)
            messages << envelope.message
          end
        end

        messages.each do |message|
          next if message.delivered?

          message.add_error("code", "message_undeliverable")
          message.on_error(nil)
        rescue => e
          error!(error: e)
        end
      end
    end
  end
end
