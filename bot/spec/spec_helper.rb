# frozen_string_literal: true

# Set to false for indefinite wait_timeout
SPEC_TIMEOUT_SECONDS = 10

# Maximum time (in seconds) an individual test is allowed to run before being killed
SPEC_EXAMPLE_TIMEOUT = 30
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

    ESM::Test.reset!
    ESM::Connection::Server.pause

    # Run the test with a timeout
    DatabaseCleaner.cleaning do
      Timeout.timeout(SPEC_EXAMPLE_TIMEOUT, nil, "Test exceeded #{SPEC_EXAMPLE_TIMEOUT}s timeout: #{example.full_description}") do
        example.run
      end
    end
  end
end

# Wait until everything is ready
# HEY! LISTEN! The following lines must be the last code to execute in this file
ESM.run!(async: true)
ESM::Test.wait_until { ESM::Database.connected? }
ESM::Test.wait_until { ESM.bot.ready? }
