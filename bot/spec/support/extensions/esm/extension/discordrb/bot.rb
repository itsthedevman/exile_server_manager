# frozen_string_literal: true

module Discordrb
  class Bot
    #
    # Test-mode override of `Discordrb::Bot#add_await!`.
    #
    # In production this registers a one-shot event listener on the gateway;
    # here it polls `ESM.discord_bot.test_inbox` until a queued reply
    # matches the filter or the timeout elapses.
    #
    # @param event_class [Class] passed through for signature compatibility;
    #   not used (the inbox doesn't model event types)
    # @param attributes [Hash] filter hash with `:from`, `:in`, `:timeout`
    #
    # @return [Struct, nil] a synthesised event, or `nil` on timeout
    #
    def add_await!(event_class, attributes = {})
      ESM.discord_bot.test_inbox.await_event(event_class, attributes)
    end
  end
end
