require "bundler/setup"
# require "bundler/gem_tasks"
require 'standalone_migrations'

StandaloneMigrations::Tasks.load_tasks

if ENV["ESM_ENV"] == "test"
  require "rspec/core/rake_task"
  require "awesome_print"
  require "pry"
  load "tasks/otr-activerecord.rake"

  OTR::ActiveRecord.configure_from_file!("config/database.yml")
  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
end

Rake.add_rakelib('tasks')

# Some db tasks require your app code to be loaded; they'll expect to find it here
task :environment do
  require_relative "lib/esm"

  ESM.console!
  # ESM.run!
end
