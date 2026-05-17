# frozen_string_literal: true

module Spec
  #
  # Audit log of messages the bot has sent out via Discordrb::Channel#send_message
  # / #send_embed (intercepted in spec/support/extensions/esm/extension/discordrb/channel.rb).
  #
  # Inherits the queue + mutex + polling primitive from {Spec::Mailbox}. Reads
  # peek (consume: false) — multiple assertions in a single example are expected
  # to inspect the same log.
  #
  class Outbox < Mailbox
    include Enumerable

    Message = Struct.new(:destination, :content)

    # Inline snapshot rather than `to_a.each` — `include Enumerable` puts
    # Enumerable's `to_a` ahead of Mailbox's in the ancestor chain, and
    # Enumerable's `to_a` is implemented via `each`. Calling `to_a` from
    # `each` would recurse through Enumerable forever.
    def each(&block)
      @mutex.synchronize { @items.dup }.each(&block)
    end

    #
    # Append `content` sent to `channel`. Returns the content unchanged so the
    # Discordrb::Channel monkey-patch can keep its return value compatible.
    #
    def store(content, channel)
      push(Message.new(channel, content))
      content
    end

    #
    # Find the first message whose content matches `needle`. Polls until match
    # or timeout. With `needle: nil` it matches the first message regardless of
    # content.
    #
    # For `ESM::Embed` content the match runs against `title` then `description`;
    # for plain strings it runs against the string itself.
    #
    # @param needle [Regexp, String, nil]
    # @param timeout [Numeric]
    #
    # @return [Message, nil] the first matching message, or nil on timeout
    #
    def retrieve(needle = nil, timeout: DEFAULT_TIMEOUT)
      wait(timeout: timeout) do |message|
        next true if needle.nil?

        match_content?(message.content, needle)
      end
    end

    #
    # Block until the queue has at least `n` messages. Raises on timeout to
    # match `wait_for { ... }.to eq(N)` semantics — the spec stops with a
    # helpful message instead of silently continuing.
    #
    # @param n [Integer]
    # @param timeout [Numeric]
    #
    # @return [true]
    # @raise [RuntimeError] when the deadline passes before the threshold is reached
    #
    def await_size(n, timeout: DEFAULT_TIMEOUT)
      deadline = Time.now + timeout

      loop do
        return true if size >= n
        
        if Time.now >= deadline
          raise "test_outbox#await_size: expected at least #{n} message(s), still at #{size} after #{timeout}s"
        end

        sleep POLL_INTERVAL
      end
    end

    #
    # The most recent message's content (or nil when the outbox is empty).
    # Non-blocking by design — matches the original `ESM::Test.messages.latest`
    # behavior. Specs that need to wait for the message to arrive should call
    # {#await_size} or {#retrieve} explicitly first.
    #
    # @return [Object, nil]
    #
    def latest
      to_a.last&.content
    end

    def contents
      to_a.map(&:content)
    end

    def destinations
      to_a.map(&:destination)
    end

    def [](index)
      to_a[index]
    end

    def first
      to_a.first
    end

    def second
      to_a[1]
    end

    def last
      to_a.last
    end

    private

    def match_content?(content, needle)
      if content.is_a?(ESM::Embed)
        content.title&.match?(needle) || content.description&.match?(needle)
      else
        content&.match?(needle)
      end
    end
  end
end
