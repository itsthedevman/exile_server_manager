# frozen_string_literal: true

module Spec
  #
  # In-memory replacement for Discord's gateway-bound await! / add_await!.
  # Specs queue replies via #queue_reply; lib/ code calls await! and a test
  # extension routes the call here, returning a synthesised event that
  # responds to #message and #user the same way Discordrb does.
  #
  # Inherits the queue + mutex + polling primitive from {Spec::Mailbox}; this
  # subclass only contributes the role-specific verbs and the event synthesis.
  #
  class Inbox < Mailbox
    #
    # Queue a reply that the next matching await call will return.
    #
    # @param from [Discordrb::User, Integer, String, nil] who is "replying".
    #   `nil` queues a wildcard reply that matches any awaiting user.
    # @param content [String] the reply message content
    # @param channel [Discordrb::Channel, Integer, String, nil] where the
    #   reply lands. `nil` matches any channel.
    #
    def queue_reply(from:, content:, channel: nil)
      push({
        user_id: from && resolve_id(from),
        channel_id: channel && resolve_id(channel),
        content: content
      }.to_istruct)
    end

    #
    # Pop the next reply addressed to `user` (or a wildcard reply with
    # `user_id: nil`), waiting up to `timeout` seconds.
    #
    # Wraps `Discordrb::User#await!` for tests. That method is overridden in
    # `spec/support/extensions/esm/extension/discordrb/user.rb` to call this method instead of
    # opening a gateway listener.
    #
    # @param user [Discordrb::User] the user the spec subject is awaiting
    # @param timeout [Numeric, nil] seconds to wait; `nil` uses
    #   {Mailbox::DEFAULT_TIMEOUT}
    #
    # @return [Struct, nil] a synthesised event responding to `#message`,
    #   `#user`, and `#channel`; `nil` if the timeout elapsed
    #
    def await_message_from(user, timeout: nil)
      reply = wait(timeout: timeout, consume: true) { |r| r.user_id.nil? || r.user_id == user.id }
      return if reply.nil?

      synthesize_event(reply)
    end

    #
    # Pop the next reply matching the `:from` (user_id) and `:in`
    # (channel_id) filters in `attributes`.
    #
    # Mirrors `Discordrb::Bot#add_await!` semantics. The bot extension at
    # `spec/support/extensions/esm/extension/discordrb/bot.rb` overrides
    # `add_await!` to call this method.
    #
    # @param _event_class [Class] kept for signature compatibility with the
    #   real `add_await!`; not used (we don't model event types in tests)
    # @param attributes [Hash] filter hash with `:from`, `:in`, `:timeout`
    #
    # @return [Struct, nil] a synthesised event, or `nil` on timeout
    #
    def await_event(_event_class, attributes)
      from_id = attributes[:from]&.to_i
      channel_id = attributes[:in]&.to_i

      reply = wait(timeout: attributes[:timeout], consume: true) do |r|
        (from_id.nil? || r.user_id == from_id) &&
          (channel_id.nil? || r.channel_id == channel_id)
      end

      return if reply.nil?

      synthesize_event(reply)
    end

    private

    def resolve_id(value)
      return value.id if value.respond_to?(:id)

      value.to_i
    end

    def synthesize_event(reply)
      {
        message: {content: reply.content},
        user: {id: reply.user_id},
        channel: {id: reply.channel_id}
      }.to_istruct
    end
  end
end
