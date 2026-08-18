class UpdaterOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :server_settings, :updater_timeout_ms, :integer
    add_column :server_settings, :updater_log_path, :text
  end
end
