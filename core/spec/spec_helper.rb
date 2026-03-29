# frozen_string_literal: true

require "bundler/setup"
require "active_support/all"
require "ostruct"

# Load database connection and ApplicationRecord first
require_relative "support/database"

# Load ESM stubs before loading the gem
require_relative "support/esm_stubs"

# Load the gem
require "esm"

# Load all models from the gem
gem_lib_path = File.expand_path("../lib", __dir__)
Dir[File.join(gem_lib_path, "esm", "models", "*.rb")].sort.each { |f| require f }

# Load test dependencies
require "faker"
require "factory_bot"
require "database_cleaner/active_record"

# Load support files (excluding factories, which are loaded by FactoryBot)
Dir[File.join(__dir__, "support", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # DatabaseCleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
