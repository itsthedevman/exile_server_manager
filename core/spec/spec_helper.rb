# frozen_string_literal: true

#
# Core has no Gemfile of its own; the .envrc points BUNDLE_GEMFILE at
# service/Gemfile so `bundle exec rspec` here resolves against service's
# installed gems. Loading is centralized via `Loader` so service, website,
# and this spec suite can't drift on order.
#

require "bundler/setup"

[
  "active_support",
  "active_support/all",
  "action_view",
  "ostruct",
  "semantic",
  "neatjson",
  "fast_jsonparser",
  "colorize",
  "http",
  "discordrb",
  "i18n",
  "everythingrb/prelude",
  "everythingrb/all"
].each { |gem| require gem }

# Establishes the AR connection and defines top-level ApplicationRecord (used by
# the support harness; ESM::ApplicationRecord is what the gem's models inherit).
require_relative "support/database"

ESM_CORE_PATH = Pathname.new(File.expand_path("..", __dir__)).freeze unless defined?(ESM_CORE_PATH)

# Centralized loader (file/dir/load_commands).
require ESM_CORE_PATH.join("lib", "loader.rb")

Loader.load_rails_extensions

# Module entry point. Defines `module ESM` with logging methods.
Loader.file("core", "lib", "esm.rb")

# Logger TRACE patch (on stdlib Logger) + ESM::Logger styled subclass.
Loader.dir("core", "lib", "extensions")
Loader.dir("core", "lib", "utilities")
Loader.file("core", "lib", "esm", "logger.rb")

# Stubs ESM.env / ESM.config / ESM.backtrace_cleaner for the test harness.
require_relative "support/esm_stubs"

# I18n must be populated before concrete commands are required. Argument
# descriptions resolve via I18n at class-definition time and will raise
# "description must be at least 1 character long" otherwise.
I18n.load_path += Dir[ESM_CORE_PATH.join("config", "locales", "**", "*.yml")]
I18n.reload!

# Eager-load the rest of core/lib/esm/ in the canonical dependency order:
# ApplicationRecord (model parent) first, then the bulk of esm/, then the
# command framework via load_commands.
Loader.file("core", "lib", "esm", "application_record.rb")
Loader.dir("core", "lib", "esm",
  except: [
    "/command/",
    "/application_record.rb",
    "/application_command.rb",
    "/logger.rb"
  ])
Loader.load_commands

# Test dependencies
require "faker"
require "factory_bot"
require "database_cleaner/active_record"

# Load support files (excluding factories, which are loaded by FactoryBot).
Dir[File.join(__dir__, "support", "**", "*.rb")].each do |f|
  next if f.include?("/factories/")

  require f
end

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

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    # Most examples roll back on a single connection. Ones that spawn threads with their own connections
    # (:multi_connection) need their setup actually committed to be visible across connections, so they clean by
    # truncation instead.
    DatabaseCleaner.strategy = example.metadata[:multi_connection] ? :truncation : :transaction
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
