class AddPackagingToServerRewards < ActiveRecord::Migration[8.1]
  def change
    add_column :server_rewards, :name, :string
    add_column :server_rewards, :enabled, :boolean, default: true, null: false
  end
end
