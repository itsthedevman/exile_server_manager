# frozen_string_literal: true

module ESM
  class ServerSetting < ApplicationRecord
    CONFIG_DEFAULTS = {
      connection_uri: "",
      log_level: "info",
      logging_path: "",
      extdb_conf_path: "",
      extdb_conf_header_name: "exile",
      extdb_version: 3,
      log_output: "extension",
      database_uri: "",
      server_mod_name: "@ExileServer",
      number_locale: "en",
      exile_logs_search_days: 14,
      additional_logs: []
    }.freeze

    attribute :server_id, :integer

    #############################################
    # Settings sent via post init
    #############################################
    # Whether to enforce if the player can gamble with their locker being full
    # When true, prevents gambling if player's poptabs exceed a specified threshold
    attribute :gambling_locker_limit_enabled, :boolean, default: true

    # Base payout percentage for gambling (e.g., 95 means 95% of bet is returned on win)
    attribute :gambling_payout_base, :integer, default: 95

    # Modifier applied to gambling payouts (multiplier for winnings)
    attribute :gambling_modifier, :integer, default: 1

    # Minimum value for the random factor in gambling payout calculation
    attribute :gambling_payout_randomizer_min, :float, default: 0

    # Middle value for the random factor in gambling payout calculation
    attribute :gambling_payout_randomizer_mid, :float, default: 0.5

    # Maximum value for the random factor in gambling payout calculation
    attribute :gambling_payout_randomizer_max, :float, default: 1

    # Percentage chance of winning a gamble (e.g., 35 means 35% chance to win)
    attribute :gambling_win_percentage, :integer, default: 35

    # Whether to log when a player is added to a territory
    attribute :logging_add_player_to_territory, :boolean, default: true

    # Whether to log when a player is demoted
    attribute :logging_demote_player, :boolean, default: true

    # Whether to log executions of commands
    attribute :logging_exec, :boolean, default: true

    # Whether to log gambling activities
    attribute :logging_gamble, :boolean, default: false

    # Whether to log modifications to player data
    attribute :logging_modify_player, :boolean, default: true

    # Whether to log payments made to territories
    attribute :logging_pay_territory, :boolean, default: true

    # Whether to log when a player is promoted
    attribute :logging_promote_player, :boolean, default: true

    # Whether to log when a player is removed from a territory
    attribute :logging_remove_player_from_territory, :boolean, default: true

    # Whether to log when a player is rewarded
    attribute :logging_reward_player, :boolean, default: true

    # Whether to log poptabs transfers between players
    attribute :logging_transfer_poptabs, :boolean, default: true

    # Whether to log territory upgrades
    attribute :logging_upgrade_territory, :boolean, default: true

    # Maximum number of payments allowed (0 for unlimited)
    attribute :max_payment_count, :integer, default: 0

    # Tax percentage applied to territory payments
    attribute :territory_payment_tax, :integer, default: 0

    # Tax percentage applied to territory upgrades
    attribute :territory_upgrade_tax, :integer, default: 0

    # Price per object in a territory
    attribute :territory_price_per_object, :integer, default: 10

    # Lifetime of a territory in days
    attribute :territory_lifetime, :integer, default: 7

    # Hour of the day when server restarts
    attribute :server_restart_hour, :integer, default: 3

    # Minute of the hour when server restarts
    attribute :server_restart_min, :integer, default: 0

    #############################################
    # Settings stored in config.yml
    #############################################
    # Do not add defaults to these
    # I only want the website to show if something as been set

    # Additional log files to include in searches
    attribute :additional_logs, :json

    # Database connection URI string
    attribute :database_uri, :text

    # Number of days of logs to search
    attribute :exile_logs_search_days, :integer

    # ExtDB config section name
    attribute :extdb_conf_header_name, :string

    # Path to ExtDB config file
    attribute :extdb_conf_path, :text

    # ExtDB version override
    attribute :extdb_version, :integer

    # Where to send SQF logs (rpt/extension/both)
    attribute :log_output, :string

    # ESM extension log file path
    attribute :logging_path, :text

    # Number formatting locale
    attribute :number_locale, :string

    # Exile server mod directory name
    attribute :server_mod_name, :string

    #############################################
    # V1
    #############################################
    alias_attribute :extdb_path, :extdb_conf_path
    attribute :request_thread_type, :string, default: "exile"
    attribute :request_thread_tick, :float, default: 0.1

    belongs_to :server
  end
end
