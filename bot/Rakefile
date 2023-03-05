require "bundler/setup"
# require "bundler/gem_tasks"
require "standalone_migrations"
require "standard/rake"

# HOTFIX: StandaloneMigrations 7.1.0 uses #exists?, which is removed in 3.2
# They have yet to patch it 12023-Mar-04
class File
  class << self
    alias_method :exists?, :exist?
  end
end

StandaloneMigrations::Tasks.load_tasks

if ENV["ESM_ENV"] == "test"
  require "rspec/core/rake_task"
  require "awesome_print"
  require "pry"
  load "tasks/otr-activerecord.rake"

  OTR::ActiveRecord.configure_from_file!("config/database.yml")
  RSpec::Core::RakeTask.new(:spec)

  task default: :spec
end

Rake.add_rakelib("tasks/migrations")

task default: [:test, "standard:fix"]

# Some db tasks require your app code to be loaded; they'll expect to find it here
task :environment do
end

task :bot do
  require_relative "lib/esm"

  ESM.console!
  # ESM.run!
end
