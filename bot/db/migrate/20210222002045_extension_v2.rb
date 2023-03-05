# frozen_string_literal: true

class ExtensionV2 < ActiveRecord::Migration[6.0]
  def change
    rename_column(:server_settings, :gambling_payout, :gambling_payout_base)
    rename_column(:server_settings, :gambling_randomizer_min, :gambling_payout_randomizer_min)
    rename_column(:server_settings, :gambling_randomizer_mid, :gambling_payout_randomizer_mid)
    rename_column(:server_settings, :gambling_randomizer_max, :gambling_payout_randomizer_max)
    rename_column(:server_settings, :gambling_win_chance, :gambling_win_percentage)
    rename_column(:server_settings, :logging_reward, :logging_reward_player)
    rename_column(:server_settings, :logging_transfer, :logging_transfer_poptabs)

    add_column(:servers, :server_version, :string)
    add_column(:server_rewards, :reward_id, :string)
    add_column(:server_rewards, :reward_vehicles, :json)
    add_column(:server_rewards, :cooldown_quantity, :integer)
    add_column(:server_rewards, :cooldown_type, :string)

    add_index(:server_rewards, [:server_id, :reward_id], unique: true)
  end
end
