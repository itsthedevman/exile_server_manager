class AddGambleSetting < ActiveRecord::Migration[7.1]
  def change
    add_column(:server_settings, :gambling_locker_limit_enabled, :bool, null: false, default: true)
  end
end
