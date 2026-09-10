# frozen_string_literal: true

# The live run. Nothing in spec/support/mocks is loaded, so Steam is the real Web API and the bot opens a real
# gateway. These specs exist to prove that the data the rest of the suite fakes still comes back in the shape it is
# faked in, which is the one thing a mocked suite structurally cannot tell you.
#
# Reached through `bin/spec-live`, never through `.rspec`. Specs live in spec/live.

require_relative "spec_helper"

GATEWAY_READY_TIMEOUT_SECONDS = 30

RSpec.configure do |config|
  # ESM.run! hands the gateway off to a thread and returns immediately, so without this the first example races
  # Discord's ready event and reads an empty guild cache. That failure looks like "the bot is not in this guild",
  # which is the one thing these specs exist to distinguish from a broken handler, so it is waited on once here
  # rather than polled for in every spec.
  config.before :suite do
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + GATEWAY_READY_TIMEOUT_SECONDS

    until ESM.discord_bot.ready?
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise "The Discord gateway was not ready within #{GATEWAY_READY_TIMEOUT_SECONDS}s. The process is running " \
              "and connected, so the likely causes are a token that cannot log in or an outbound connection that " \
              "never completed the handshake."
      end

      sleep 0.1
    end
  end

  config.around do |example|
    trace!(
      example_group: example.example_group&.description,
      example: example.description
    )

    DatabaseCleaner.cleaning { example.run }
  end

  # The mock run clears its message stores here too. There are none without the fakes, so what is left is the part
  # that applies either way: a stray background thread can leave a PG connection half reset, and disconnect! evicts
  # every connection so the retry gets a fresh one.
  config.retry_callback = proc do |_example|
    ActiveRecord::Base.connection_pool.disconnect!
  end
end

# This must be the last line in this file.
#
# `async: true` because the real #run hands off to discordrb, which blocks for the life of the process otherwise.
# Note that it returns as soon as the connection is handed off, not when the guild cache is populated; a spec that
# needs a guild has to wait for it rather than assume.
#
# `features: []` deliberately excludes command_hooks. Registering slash commands against a token the dev bot is
# already holding is how you get every command answered twice. The gateway still comes up regardless, because
# ESM.run! calls discord_bot.run unconditionally rather than behind a feature.
ESM.run!(async: true, features: [])
