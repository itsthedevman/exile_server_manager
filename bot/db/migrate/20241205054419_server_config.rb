class ServerConfig < ActiveRecord::Migration[7.2]
  def change
    change_table :server_settings do |t|
      # Renames
      t.rename(:extdb_path, :extdb_conf_path)

      # New columns
      t.string :extdb_conf_header_name
      t.integer :extdb_version
      t.string :log_output
      t.text :database_uri
      t.string :server_mod_name
      t.string :number_locale
      t.integer :exile_logs_search_days
      t.json :additional_logs, default: []
    end
  end
end
