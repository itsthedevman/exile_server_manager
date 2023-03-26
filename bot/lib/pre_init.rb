# frozen_string_literal: true

#############################
# Load Extensions
#############################
Dir["#{__dir__}/esm/extension/**/*.rb"].sort.each { |extension| require extension }

#############################
# DB migrations
#############################
module Rails
  def self.root
    Dir.pwd
  end
end

#############################
# Autoload ESM
#############################
loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.inflector.inflect("esm" => "ESM", "ostruct" => "OpenStruct", "xm8" => "XM8", "api" => "API", "json" => "JSON")

# Convert ESM::Model::Server -> ESM::Server
loader.collapse("#{__dir__}/esm/model")

# Forces the jobs to be loaded on the Root path
# ESM::Jobs::SomeJob -> SomeJob
loader.push_dir("#{__dir__}/esm/jobs")

# Don't load extensions, we do that above
loader.ignore("#{__dir__}/esm/extension")

# Ignore preinits
loader.ignore("#{__dir__}/pre_init.rb")
loader.ignore("#{__dir__}/pre_init_dev.rb")
loader.ignore("#{__dir__}/esm/database.rb")

# gemspec expects this file, but Zeitwerk does not like it
loader.ignore("#{__dir__}/esm/version.rb")
loader.ignore("#{__dir__}/esm/esm.rb")

# Load everything right meow
loader.setup
loader.eager_load

#############################
# Configure Inflector
#############################
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym("ESM")
end

#############################
# Initializers
#############################
ESM.initialize_i18n
ESM.initialize_logger
ESM.initialize_steam
ESM.initialize_redis

ESM::Notifications.subscribe
ESM::Arma::ClassLookup.cache
