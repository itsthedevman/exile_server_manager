class CooldownsUniqueKey < ActiveRecord::Migration[8.1]
  # A cooldown is logically unique per (command, player, community, server) - keyed by steam_uid for registration-gated
  # commands and user_id otherwise. The bot never had to enforce that in the database because Discord runs a user's
  # commands serially; website-initiated commands can arrive concurrently, so the uniqueness now has to hold in the
  # schema itself rather than leaning on serialized execution.
  #
  # The pre-existing indexes were non-unique and omitted server_id (the query filtered it as a residual). These
  # replacements match the real lookup key exactly.
  def up
    remove_index :cooldowns, name: "index_cooldowns_on_command_name_and_steam_uid_and_community_id"
    remove_index :cooldowns, name: "index_cooldowns_on_command_name_and_user_id_and_community_id"

    add_index :cooldowns, [:command_name, :steam_uid, :community_id, :server_id],
      unique: true, name: "index_cooldowns_on_steam_uid_key"
    add_index :cooldowns, [:command_name, :user_id, :community_id, :server_id],
      unique: true, name: "index_cooldowns_on_user_id_key"
  end

  def down
    remove_index :cooldowns, name: "index_cooldowns_on_steam_uid_key"
    remove_index :cooldowns, name: "index_cooldowns_on_user_id_key"

    add_index :cooldowns, [:command_name, :steam_uid, :community_id],
      name: "index_cooldowns_on_command_name_and_steam_uid_and_community_id"
    add_index :cooldowns, [:command_name, :user_id, :community_id],
      name: "index_cooldowns_on_command_name_and_user_id_and_community_id"
  end
end
