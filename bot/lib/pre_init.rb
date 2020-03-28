# frozen_string_literal: true

#############################
# Load Extensions
#############################
Dir["#{__dir__}/esm/extension/**/*.rb"].each { |extension| require extension }

#############################
# Load Dotenv variables
#############################
Dotenv.load
Dotenv.load(".env.test") if ENV["ESM_ENV"] == "test"

#############################
# Autoload ESM
#############################
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("esm" => "ESM", "ostruct" => "OpenStruct")

# Convert ESM::Model::Server -> ESM::Server
loader.collapse("#{__dir__}/esm/model")

# Don't load extensions, we do that above
loader.ignore("#{__dir__}/esm/extension")

# Ignore this file!
loader.ignore("#{__dir__}/pre_init.rb")

# gemspec expects this file, but Zeitwerk does not like it
loader.ignore("#{__dir__}/esm/version.rb")

# Load everything right meow
loader.setup
loader.eager_load

#############################
# Load Locales
#############################
I18n.load_path += Dir[File.expand_path("config/locales/**") + "/*.yml"]
I18n.default_locale = "en-US"
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
