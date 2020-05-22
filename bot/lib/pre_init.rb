# frozen_string_literal: true

#############################
# Load Extensions
#############################
Dir["#{__dir__}/esm/extension/**/*.rb"].each { |extension| require extension }

#############################
# Autoload ESM
#############################
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("esm" => "ESM", "ostruct" => "OpenStruct", "xm8" => "XM8")

# Convert ESM::Model::Server -> ESM::Server
loader.collapse("#{__dir__}/esm/model")

# Don't load extensions, we do that above
loader.ignore("#{__dir__}/esm/extension")

# Ignore preinits
loader.ignore("#{__dir__}/pre_init.rb")
loader.ignore("#{__dir__}/pre_init_dev.rb")

# gemspec expects this file, but Zeitwerk does not like it
loader.ignore("#{__dir__}/esm/version.rb")
loader.ignore("#{__dir__}/esm/esm.rb")

# Load everything right meow
loader.setup
loader.eager_load
