# frozen_string_literal: true

# Set our env to test
ENV["ESM_ENV"] = "test"

# Start SimpleCov
if ENV["TRAVIS"].nil?
  require "simplecov"
  SimpleCov.start
end

require "bundler/setup"
require "esm"
require "rspec/wait"
require "database_cleaner"
require "factory_bot"
require "faker"
require "byebug"
require "awesome_print"
require "pry"
require "ruby-prof"

# Start the bot
ESM.run!

# Require all our supports
Dir["#{File.expand_path("./spec/support")}/**/*.rb"].each do |file|
  if file.match(/commands\/.+\.rb$/i)
    ESM::Command.process_command(file, "test")
  else
    require file
  end
end

# Ignore debug messages when running tests
ActiveRecord::Base.logger.level = Logger::INFO

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Timeout for rspec/wait, default timeout for requests
  config.wait_timeout = 10 # seconds

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before :suite do
    FactoryBot.find_definitions
    DatabaseCleaner.clean_with :deletion
    DatabaseCleaner.strategy = :deletion
  end

  config.before :example do
    ESM::Test.reset!
  end

  config.after :example do
    ESM::Test.skip_cooldown = false
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end

    ESM::Websocket.remove_all_connections!
  end
end

def create_request(**params)
  user = ESM.bot.user(ESM::User::Bryan::ID)
  command = ESM::Command::Test::Base.new

  ESM::Websocket::Request.new(
    command: command,
    user: user,
    channel: ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL),
    parameters: params
  )
end

# Wait until the bot has fully connected
ESM::Test.wait_until { ESM.bot.ready? }

# Clean the database
ESM::Database.clean!
