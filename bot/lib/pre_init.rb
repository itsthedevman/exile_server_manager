# frozen_string_literal: true

timer = Timer.start!

#############################
# Must be ran before autoload
#############################
I18n.load_path += Dir[File.expand_path("config/locales/**/*.yml")]
I18n.reload!

# Steam
SteamWebApi.configure do |config|
  config.api_key = ESM.config.steam_api_key
end

# Make the computer understand us
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym("ESM")
  inflect.acronym("ID")
  inflect.acronym("UID")
end

# Make active support happy
ActiveSupport::Cache.format_version = 7.1
ActiveSupport.to_time_preserves_timezone = true # Rails 8

# Required by standalone_migrations
module Rails
  def self.root
    Dir.pwd
  end
end

#############################
# Autoload ESM
#############################
ESM.loader.tap do |loader|
  loader.inflector.inflect(
    "esm" => "ESM",
    "ostruct" => "OpenStruct",
    "xm8" => "XM8",
    "api" => "API",
    "json" => "JSON"
  )

  # Convert ESM::Model::Server -> ESM::Server
  loader.collapse(ESM.root.join("lib", "esm", "model"))

  # Forces the jobs to be loaded on the Root path
  # ESM::Jobs::SomeJob -> SomeJob
  loader.push_dir(ESM.root.join("lib", "esm", "jobs"))

  # Don't load extensions, we do that above
  loader.ignore(ESM.root.join("lib", "esm", "extension"))

  # Ignore inits
  loader.ignore(ESM.root.join("lib", "esm", "database.rb"))
  loader.ignore(ESM.root.join("lib", "post_init.rb"))
  loader.ignore(ESM.root.join("lib", "post_init_dev.rb"))
  loader.ignore(ESM.root.join("lib", "pre_init.rb"))
  loader.ignore(ESM.root.join("lib", "pre_init_dev.rb"))

  # gemspec expects this file, but Zeitwerk does not like it
  loader.ignore(ESM.root.join("lib", "esm", "version.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "esm.rb"))
end

info!("Completed in #{timer.stop!}s")
