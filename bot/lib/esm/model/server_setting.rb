# frozen_string_literal: true

module ESM
  class ServerSetting < ApplicationRecord
    attribute :server_id, :integer
    attribute :extdb_path, :text, default: nil
    attribute :gambling_payout, :integer, default: 95
    attribute :gambling_modifier, :integer, default: 1
    attribute :gambling_randomizer_min, :float, default: 0
    attribute :gambling_randomizer_mid, :float, default: 0.5
    attribute :gambling_randomizer_max, :float, default: 1
    attribute :gambling_win_chance, :integer, default: 35
    attribute :logging_path, :text, default: nil
    attribute :logging_add_player_to_territory, :boolean, default: true
    attribute :logging_demote_player, :boolean, default: true
    attribute :logging_exec, :boolean, default: true
    attribute :logging_gamble, :boolean, default: false
    attribute :logging_modify_player, :boolean, default: true
    attribute :logging_pay_territory, :boolean, default: true
    attribute :logging_promote_player, :boolean, default: true
    attribute :logging_remove_player_from_territory, :boolean, default: true
    attribute :logging_reward, :boolean, default: true
    attribute :logging_transfer, :boolean, default: true
    attribute :logging_upgrade_territory, :boolean, default: true
    attribute :max_payment_count, :integer, default: 0
    attribute :request_thread_type, :string, default: "exile"
    attribute :request_thread_tick, :float, default: 0.1
    attribute :territory_payment_tax, :integer, default: 0
    attribute :territory_upgrade_tax, :integer, default: 0
    attribute :territory_price_per_object, :integer, default: 10
    attribute :territory_lifetime, :integer, default: 7
    attribute :server_restart_hour, :integer, default: 3
    attribute :server_restart_min, :integer, default: 0

    belongs_to :server
  end
end
