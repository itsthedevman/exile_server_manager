# frozen_string_literal: true

# Set to false for indefinite wait_timeout
SPEC_TIMEOUT_SECONDS = 10

LOG_LEVEL = false

require_relative "config"

RSpec.configure do |config|
  config.before :suite do
    FactoryBot.definition_file_paths = [ESM.root.join("spec", "support", "factories")]
    FactoryBot.find_definitions

    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner[:active_record, db: ESM::ExileAccount].strategy = :deletion
    DatabaseCleaner.clean
  end

  config.around do |example|
    trace!(
      example_group: example.example_group&.description,
      example: example.description
    )

    ESM::Test.messages.clear
    ESM::Test.territory_admin_uids = []
    ESM::Test.skip_cooldown = false
    ESM.discord_bot.test_inbox.clear
    ESM.discord_bot.delivery_overseer.queue.clear
    ESM::Connection::Server.pause

    cache_snapshot = ESM.discord_bot.snapshot

    begin
      DatabaseCleaner.cleaning { example.run }
    ensure
      ESM.discord_bot.restore(cache_snapshot)
    end
  end
end

# These must be the last lines in this file. ESM.run! triggers post-init
# (database connection, command load) and the bot's no-op #run override that
# flips @esm_status to :ready. No gateway connection.
ESM.run!
