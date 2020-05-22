# frozen_string_literal: true

# Set our env to test
ENV["ESM_ENV"] = "test"

require "bundler/setup"
require "esm"
require "rspec/wait"
require "database_cleaner"
require "factory_bot"
require "faker"
require "awesome_print"
require "pry"
require "pry-nav"
require "colorize"
require "ruby-prof"
require "rspec/expectations"

# Load all of our support files
loader = Zeitwerk::Loader.new
loader.inflector.inflect("esm" => "ESM")
loader.push_dir("#{__dir__}/support")
loader.collapse("#{__dir__}/support/model")

# Load everything right meow
loader.setup
loader.eager_load

# Start the bot
ESM.run!

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# Load all of our test commands
Dir["#{__dir__}/support/esm/command/test/*.rb"].each do |file|
  ESM::Command.process_command(file, "test")
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
