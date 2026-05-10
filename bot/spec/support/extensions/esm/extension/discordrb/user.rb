# frozen_string_literal: true

module Discordrb
  class User
    #
    # Test-mode override of `Discordrb::User#await!`.
    #
    # In production this opens a blocking gateway await for the user's next
    # message; here it polls `ESM.discord_bot.test_inbox` so specs can
    # synthesise the reply via `test_inbox.queue_reply(from: user, ...)`.
    #
    # @param attributes [Hash] forwarded for compatibility; only `:timeout`
    #   is consumed
    #
    # @return [Struct, nil] a synthesised event, or `nil` on timeout
    #
    def await!(attributes = {})
      ESM.discord_bot.test_inbox.await_message_from(self, timeout: attributes[:timeout])
    end
  end
end
