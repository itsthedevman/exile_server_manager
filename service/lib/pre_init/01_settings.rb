# frozen_string_literal: true

#
# Initializes the `config` gem and loads YAML config into the `Settings`
# constant. Load order is:
#
#   1. config/settings.yml                  (committed defaults)
#   3. config/settings.local.yml            (gitignored user secrets)
#   2. config/settings/#{ESM_ENV}.yml       (committed per-env overlays)
#
# `ESM_ENV` stays an env var because it picks which YAML files Settings reads,
# so it has to be resolved before Settings exists.
#

Config.setup do |config|
  config.const_name = "Settings"
  config.evaluate_erb_in_yaml = true

  # Keys alpha-sorted top-level and within each hash. Field semantics, units,
  # and override locations are documented inline in config/settings.yml.
  config.schema do
    required(:base_url).filled(:string)

    required(:bot_delivery_overseer).hash do
      required(:check_every).filled { int? | float? }
    end

    required(:cache).hash do
      required(:community_ids).value(:integer)
      required(:server_ids).value(:integer)
    end

    required(:connection_client).hash do
      required(:max_queue).filled(:integer)
      required(:max_threads).filled(:integer)
      required(:min_threads).filled(:integer)
      required(:request_check).filled { int? | float? }
      required(:response_timeout).filled { int? | float? }
    end

    required(:connection_server).hash do
      required(:connection_check).filled { int? | float? }
      required(:heartbeat_timeout).filled { int? | float? }
      required(:lobby_timeout).filled { int? | float? }
    end

    required(:dev_user_allowlist).array(:string)
    required(:developer_guild_id).value(:string)
    required(:error_logging_channel_id).value(:string)

    required(:nats).hash do
      required(:shared_secret).filled(:string)
      required(:subject_prefix).filled(:string)
      required(:url).filled(:string)
    end

    required(:ports).hash do
      required(:api).filled(:integer)
      required(:connection_server).filled(:integer)
      required(:websocket).filled(:integer)
    end

    required(:print_to_stdout).value(:bool)

    required(:request_overseer).hash do
      required(:check_every).filled { int? | float? }
    end

    required(:steam_api_key).filled(:string)
    required(:tips).array(:string)
    required(:token).filled(:string)

    required(:websocket_connection_overseer).hash do
      required(:check_every).filled { int? | float? }
    end

    required(:websocket_request_overseer).hash do
      required(:check_every).filled { int? | float? }
    end
  end
end

config_path = Loader.service_path.join("config")
environment = ENV["ESM_ENV"].presence || "development"

Config.load_and_set_settings(
  config_path.join("settings.yml"),
  config_path.join("settings.local.yml"),
  config_path.join("settings", "#{environment}.yml")
)
