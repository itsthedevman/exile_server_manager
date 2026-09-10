class AddCooldownsScopeKey < ActiveRecord::Migration[8.1]
  def change
    # Add the new column
    add_column :cooldowns, :scope_key, :string, null: true

    # Drop the indexes
    remove_index :cooldowns, name: "index_cooldowns_on_steam_uid_key"
    remove_index :cooldowns, name: "index_cooldowns_on_user_id_key"

    # Add them with the scope key
    add_index :cooldowns,
      [:command_name, :steam_uid, :community_id, :server_id, :scope_key],
      name: "index_cooldowns_on_steam_uid_key",
      unique: true,
      nulls_not_distinct: true,
      where: "steam_uid IS NOT NULL"

    add_index :cooldowns,
      [:command_name, :user_id, :community_id, :server_id, :scope_key],
      name: "index_cooldowns_on_user_id_key",
      unique: true,
      nulls_not_distinct: true,
      where: "user_id IS NOT NULL"
  end
end
