ENV["ESM_ENV"] = "test"

# Must execute before esm is required
if ENV["CODE_COVERAGE"] == "true"
  require "simplecov"
  SimpleCov.start
end

require "bundler/setup"
require "awesome_print"
require "colorize"
require "database_cleaner"
require "pry"
require "esm"
require "factory_bot"
require "faker"
require "rspec/expectations"
require "rspec/wait"
require "neatjson"
require "timecop"

ESM.logger.level =
  case LOG_LEVEL
  when :trace
    Logger::TRACE
  when :debug
    Logger::DEBUG
  when :info
    Logger::INFO
  when :warn
    Logger::WARN
  else
    Logger::ERROR
  end

# Load the spec related files
require_relative "./spec_helper_methods"

# Loaded separately because the rest of these files are loaded in ESM::Command
require_relative "./support/esm/command/base"

Dir["#{__dir__}/spec_*/**/*.rb"].sort.each { |extension| require extension }
Dir["#{__dir__}/support/esm/extension/**/*.rb"].sort.each { |extension| require extension }

# Load all of our support files
loader = Zeitwerk::Loader.new
loader.inflector.inflect("esm" => "ESM")
loader.push_dir("#{__dir__}/support")
loader.collapse("#{__dir__}/support/model")
loader.ignore("#{__dir__}/support/esm/extension")

# Load everything right meow
loader.setup
loader.eager_load

# Load the commands after they've been auto-loaded
ESM::Command.load

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# Ignore debug messages when running tests
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?

# Make sure these programs are not running
`kill -9 $(pgrep -f esm_bot)`
`kill -9 $(pgrep -f extension_server)`

# Build and start the server
build_result = `cargo check; echo $?`.chomp
raise "Failed to build extension_server" if build_result != "0"

EXTENSION_SERVER = IO.popen("POSTGRES_DATABASE=esm_test RUST_LOG=#{LOG_LEVEL} bin/extension_server")

RSpec::Matchers.define_negated_matcher :exclude, :include
