# frozen_string_literal: true

ENV["ESM_ENV"] = "test"
ENV["RAILS_ENV"] = "test"

require "bundler/setup"
require "awesome_print"
require "colorize"
require "database_cleaner/active_record"
require "esm"
require "factory_bot"
require "faker"
require "hashids"
require "neatjson"
require "pry"
require "rspec/expectations"
require "rspec/wait"
require "timecop"

# Load the spec related files
require_relative "methods"

# Files that have to be loaded before ESM
Dir["#{__dir__}/support/pre_load/**/*.rb"]
  .sort
  .each { |extension| require extension }

# Load the rest of our support files
ESM.loader.tap do |loader|
  loader.push_dir(ESM.root.join("spec", "support"))
  loader.collapse(ESM.root.join("spec", "support", "additions"))

  # Handled by FactoryBot
  loader.ignore(ESM.root.join("spec", "support", "factories"))

  # Loaded below
  loader.ignore(ESM.root.join("spec", "support", "spec_*"))
  loader.ignore(ESM.root.join("spec", "support", "extensions"))
end

ESM.load!

# Spec related files
Dir[ESM.root.join("spec", "support", "spec_*", "**", "*.rb")]
  .sort
  .each { |extension| require extension }

# ESM overrides and other support files
Dir[ESM.root.join("spec", "support", "extensions", "**", "*.rb")]
  .sort
  .each { |extension| require extension }

# Load the commands after they've been auto-loaded
ESM::Command.load

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
  when :error
    Logger::ERROR
  else
    Logger::UNKNOWN
  end

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# Ignore debug messages when running tests
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?

RSpec::Matchers.define_negated_matcher :exclude, :include
