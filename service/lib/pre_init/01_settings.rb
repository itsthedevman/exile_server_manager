# frozen_string_literal: true

#
# Initializes the `config` gem and loads YAML config into the `Settings`
# constant. Load order is:
#
#   1. config/settings.yml                  (committed defaults)
#   2. config/settings/#{ESM_ENV}.yml       (committed per-env overlays)
#   3. config/settings.local.yml            (gitignored user secrets)
#   4. config/settings/#{ESM_ENV}.local.yml (gitignored per-env overrides)
#
# `ESM_ENV` stays an env var because it picks which YAML files Settings reads,
# so it has to be resolved before Settings exists.
#

require "config"

Config.setup do |config|
  config.const_name = "Settings"
  config.evaluate_erb_in_yaml = true
end

Config.load_and_set_settings(
  Config.setting_files(
    Loader.service_path.join("config").to_s,
    ENV["ESM_ENV"].presence || "development"
  )
)
