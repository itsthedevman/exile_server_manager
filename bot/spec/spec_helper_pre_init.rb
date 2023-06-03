ENV["ESM_ENV"] = "test"
ENV["RAILS_ENV"] = "test"

# Must execute before esm is required
if ENV["CODE_COVERAGE"] == "true"
  require "simplecov"
  SimpleCov.start
end

require "bundler/setup"
require "awesome_print"
require "colorize"
require "database_cleaner/active_record"
require "pry"
require "factory_bot"
require "faker"
require "hashids"
require "rspec/expectations"
require "rspec/wait"
require "neatjson"
require "timecop"

###########
# Reload the extension server before starting ESM
`kill -9 $(pgrep -f esm_bot)`
`kill -9 $(pgrep -f extension_server)`

build_result = `cargo check; echo $?`.chomp
raise "Failed to build extension_server" if build_result != "0"

EXTENSION_SERVER = IO.popen("POSTGRES_DATABASE=esm_test RUST_LOG=#{LOG_LEVEL} bin/extension_server")

###########
# This starts ESM
require "esm"

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

# Spec related files
Dir["#{__dir__}/spec_*/**/*.rb"]
  .sort
  .each { |extension| require extension }

# ESM overrides and other support files
Dir["#{__dir__}/support/esm/**/*.rb"]
  .sort
  .each { |extension| require extension }

# Load the rest of our support files
loader = Zeitwerk::Loader.new
loader.inflector.inflect("esm" => "ESM")
loader.push_dir("#{__dir__}/support")

loader.collapse("#{__dir__}/support/model")
loader.ignore("#{__dir__}/support/esm")

# Load everything right meow
loader.setup
loader.eager_load

# Load the commands after they've been auto-loaded
ESM::Command.load

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# Ignore debug messages when running tests
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?

RSpec::Matchers.define_negated_matcher :exclude, :include
