class AddUuidToServer < ActiveRecord::Migration[6.1]
  # All of this just so uuid would be closer to the front...
  def change
    # Delete old foreign keys
    remove_foreign_key :logs, :servers
    remove_foreign_key :servers, :communities
    remove_foreign_key :server_mods, :servers
    remove_foreign_key :server_rewards, :servers
    remove_foreign_key :server_settings, :servers
    remove_foreign_key :territories, :servers
    remove_foreign_key :user_gamble_stats, :servers
    remove_foreign_key :user_notification_preferences, :servers
    remove_foreign_key :user_notification_routes, :servers, column: :source_server_id

    # Rename old table
    rename_table(:servers, :servers_old)

    # Recreate the table with the changes
    # Dropped :deleted_at
    # Added :uuid
    # Added :server_visibility
    # Added :server_version
    create_table :servers do |t|
      t.uuid :uuid, null: false
      t.string :server_id, null: false
      t.integer :community_id, null: false
      t.text :server_key, null: true
      t.text :server_name
      t.integer :server_visibility, null: false, default: 1
      t.string :server_ip
      t.string :server_port
      t.string :server_version
      t.datetime :server_start_time
      t.datetime :disconnected_at
      t.timestamps
    end

    # Migrate the old data over to the new table
    ESM::Server.reset_column_information
    data = execute("SELECT * FROM servers_old;")
    data.each do |server|
      server["uuid"] = SecureRandom.uuid
      ESM::Server.create!(server.except("deleted_at"))
    end

    # Delete old table
    drop_table(:servers_old)

    # Recreate the indexes
    add_index :servers, :uuid, unique: true
    add_index :servers, :server_id, unique: true
    add_index :servers, :server_key, unique: true

    # Recreate the foreign keys
    add_foreign_key :logs, :servers
    add_foreign_key :servers, :communities
    add_foreign_key :server_mods, :servers
    add_foreign_key :server_rewards, :servers
    add_foreign_key :server_settings, :servers
    add_foreign_key :territories, :servers
    add_foreign_key :user_gamble_stats, :servers
    add_foreign_key :user_notification_preferences, :servers
  end
end
