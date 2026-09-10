# frozen_string_literal: true

# The default run, and the one `.rspec` points at. Everything outside this process is replaced by a fake: Steam
# answers out of canned JSON, and the bot never opens a gateway, resolving users, servers and channels from a cache
# the factories fill.
#
# The rule for spec/support/mocks is "anything that fakes an external service". Loading it here rather than from
# pre_init means live_helper gets the real thing by simply not asking, so neither file needs a conditional.

require_relative "spec_helper"

Dir[ESM.root.join("spec", "support", "mocks", "**", "*.rb")]
  .sort
  .each { |mock| require mock }

# Half of what this defines reads the outbox the mocks above provide, so it travels with them. `wait_until` and
# `grant_command_access!` are generic and can be split back out when a live spec actually wants one.
require_relative "methods"

RSpec.configure do |config|
  config.around do |example|
    trace!(
      example_group: example.example_group&.description,
      example: example.description
    )

    ESM.discord_bot.test_outbox.clear
    ESM.discord_bot.test_inbox.clear
    ESM::Test.territory_admin_uids = []
    ESM::Test.skip_cooldown = false
    ESM.discord_bot.delivery_overseer.queue.clear
    ESM::Arma::Server.pause

    cache_snapshot = ESM.discord_bot.snapshot

    begin
      DatabaseCleaner.cleaning { example.run }
    ensure
      ESM.discord_bot.restore(cache_snapshot)
    end
  end

  # Drop the AR connection pool between attempts. The dominant residual flake
  # (`undefined method 'cmd_tuples' for nil` inside DatabaseCleaner) comes from
  # a stray background thread leaving a PG connection in a half-reset state.
  # disconnect! evicts every connection so the retry gets a fresh one. Also
  # clear the in-memory message stores so the retry's assertions don't see
  # leftovers from the failed attempt.
  config.retry_callback = proc do |_example|
    ActiveRecord::Base.connection_pool.disconnect!
    ESM.discord_bot.test_outbox.clear
    ESM.discord_bot.test_inbox.clear
  end
end

# This must be the last line in this file. ESM.run! triggers post-init
# (database connection, command load) and the bot's no-op #run override that
# flips @esm_status to :ready. No gateway connection.
#
# `nats` is left out because the one spec that needs the responder
# (spec/integration/website/api/full_wiring_spec.rb) starts and stops it itself against a throwaway broker. A
# suite-wide responder would answer on the real subject prefix for the whole run.
ESM.run!(features: %i[command_hooks websocket_v1 arma_listener jobs])
