require "bundler/setup"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
load "tasks/otr-activerecord.rake"

OTR::ActiveRecord.configure_from_file!("config/database.yml")
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

namespace :db do
  # Some db tasks require your app code to be loaded; they'll expect to find it here
  task :environment do
    require_relative "lib/esm"
  end
end
