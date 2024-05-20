# frozen_string_literal: true

require "bundler/setup"
# require "bundler/gem_tasks"
require "standalone_migrations"

# # HOTFIX: StandaloneMigrations 7.1.0 uses #exists?, which is removed in 3.2
# # They have yet to patch it 12023-Mar-04
# class File
#   class << self
#     alias_method :exists?, :exist?
#   end
# end

# HOTFIX: StandaloneMigrations
ENV["SCHEMA"] = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "schema.rb")

StandaloneMigrations::Tasks.load_tasks

# Must be required AFTER StandaloneMigrations
require_relative "lib/esm"

if ENV["ESM_ENV"] == "test"
  require "rspec/core/rake_task"
  require "awesome_print"
  require "pry"
  load "tasks/otr-activerecord.rake"

  OTR::ActiveRecord.configure_from_file!("config/database.yml")
  RSpec::Core::RakeTask.new(:spec)

  task default: :spec
end

if ["development", "test"].include?(ENV["ESM_ENV"])
  require "standard/rake"
end

Rake.add_rakelib("tasks/migrations")

task default: [:test, "standard:fix"]

# rubocop:disable Rails/RakeEnvironment
task :environment do
  ESM.load!
end

task :bot do
  ESM.run!(async: true)

  until ESM.bot.ready?
    sleep 0.1
  end
end

# rubocop:enable Rails/RakeEnvironment
