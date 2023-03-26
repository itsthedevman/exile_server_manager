# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_03_26_003042) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "bot_attributes", force: :cascade do |t|
    t.boolean "maintenance_mode_enabled", default: false, null: false
    t.string "maintenance_message"
    t.string "status_type", default: "PLAYING", null: false
    t.string "status_message"
    t.integer "community_count", default: 0
    t.integer "server_count", default: 0
    t.integer "user_count", default: 0
  end

  create_table "command_caches", force: :cascade do |t|
    t.string "command_name"
    t.string "command_type"
    t.string "command_category"
    t.text "command_description"
    t.text "command_example"
    t.text "command_usage"
    t.text "command_arguments"
    t.json "command_aliases"
    t.json "command_defines"
    t.index ["command_name"], name: "index_command_caches_on_command_name"
  end

  create_table "command_configurations", force: :cascade do |t|
    t.integer "community_id", null: false
    t.string "command_name", null: false
    t.boolean "enabled", default: true
    t.boolean "notify_when_disabled", default: true
    t.integer "cooldown_quantity", default: 2
    t.string "cooldown_type", default: "seconds"
    t.boolean "allowed_in_text_channels", default: true
    t.boolean "whitelist_enabled", default: false
    t.json "whitelisted_role_ids", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["command_name"], name: "index_command_configurations_on_command_name"
    t.index ["community_id"], name: "index_command_configurations_on_community_id"
    t.index ["deleted_at"], name: "index_command_configurations_on_deleted_at"
  end

  create_table "command_counts", force: :cascade do |t|
    t.string "command_name", null: false
    t.integer "execution_count", default: 0, null: false
    t.index ["command_name"], name: "index_command_counts_on_command_name"
  end

  create_table "communities", force: :cascade do |t|
    t.string "community_id", null: false
    t.text "community_name"
    t.string "guild_id", null: false
    t.string "logging_channel_id"
    t.boolean "log_reconnect_event", default: false
    t.boolean "log_xm8_event", default: true
    t.boolean "log_discord_log_event", default: true
    t.boolean "player_mode_enabled", default: true
    t.json "territory_admin_ids", default: []
    t.string "command_prefix"
    t.boolean "welcome_message_enabled", default: true
    t.text "welcome_message", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.json "dashboard_access_role_ids", default: []
    t.index ["community_id"], name: "index_communities_on_community_id", unique: true
    t.index ["deleted_at"], name: "index_communities_on_deleted_at"
    t.index ["guild_id"], name: "index_communities_on_guild_id", unique: true
  end

  create_table "cooldowns", force: :cascade do |t|
    t.string "command_name"
    t.integer "community_id"
    t.integer "server_id"
    t.integer "user_id"
    t.string "steam_uid"
    t.integer "cooldown_quantity"
    t.string "cooldown_type"
    t.integer "cooldown_amount", default: 0
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["command_name", "steam_uid", "community_id"], name: "index_cooldowns_on_command_name_and_steam_uid_and_community_id"
    t.index ["command_name", "user_id", "community_id"], name: "index_cooldowns_on_command_name_and_user_id_and_community_id"
  end

  create_table "downloads", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "version", null: false
    t.string "file"
    t.boolean "current_release"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_release"], name: "index_downloads_on_current_release"
  end

  create_table "log_entries", force: :cascade do |t|
    t.integer "log_id", null: false
    t.datetime "log_date", null: false
    t.string "file_name", null: false
    t.json "entries"
    t.index ["log_id", "log_date", "file_name"], name: "index_log_entries_on_log_id_and_log_date_and_file_name"
    t.index ["log_id", "log_date"], name: "index_log_entries_on_log_id_and_log_date"
    t.index ["log_id"], name: "index_log_entries_on_log_id"
  end

  create_table "logs", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "server_id", null: false
    t.text "search_text"
    t.string "requestors_user_id"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_logs_on_expires_at"
    t.index ["server_id"], name: "index_logs_on_server_id"
    t.index ["uuid"], name: "index_logs_on_uuid", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "community_id", null: false
    t.string "notification_type", null: false
    t.text "notification_title"
    t.text "notification_description"
    t.string "notification_color"
    t.string "notification_category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["community_id"], name: "index_notifications_on_community_id"
  end

  create_table "requests", force: :cascade do |t|
    t.uuid "uuid"
    t.string "uuid_short"
    t.integer "requestor_user_id"
    t.integer "requestee_user_id"
    t.string "requested_from_channel_id", null: false
    t.string "command_name", null: false
    t.json "command_arguments"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_requests_on_expires_at"
    t.index ["requestee_user_id", "uuid_short"], name: "index_requests_on_requestee_user_id_and_uuid_short", unique: true
    t.index ["uuid"], name: "index_requests_on_uuid"
  end

  create_table "server_mods", force: :cascade do |t|
    t.integer "server_id", null: false
    t.text "mod_name", null: false
    t.text "mod_link"
    t.string "mod_version"
    t.boolean "mod_required", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_server_mods_on_deleted_at"
    t.index ["server_id"], name: "index_server_mods_on_server_id"
  end

  create_table "server_rewards", force: :cascade do |t|
    t.integer "server_id", null: false
    t.json "reward_items", default: {}
    t.bigint "player_poptabs", default: 0
    t.bigint "locker_poptabs", default: 0
    t.bigint "respect", default: 0
    t.datetime "deleted_at"
    t.string "reward_id"
    t.json "reward_vehicles"
    t.integer "cooldown_quantity"
    t.string "cooldown_type"
    t.index ["deleted_at"], name: "index_server_rewards_on_deleted_at"
    t.index ["server_id", "reward_id"], name: "index_server_rewards_on_server_id_and_reward_id", unique: true
    t.index ["server_id"], name: "index_server_rewards_on_server_id"
  end

  create_table "server_settings", force: :cascade do |t|
    t.integer "server_id"
    t.text "extdb_path"
    t.integer "gambling_payout_base", default: 95
    t.integer "gambling_modifier", default: 1
    t.float "gambling_payout_randomizer_min", default: 0.0
    t.float "gambling_payout_randomizer_mid", default: 0.5
    t.float "gambling_payout_randomizer_max", default: 1.0
    t.integer "gambling_win_percentage", default: 35
    t.text "logging_path"
    t.boolean "logging_add_player_to_territory", default: true
    t.boolean "logging_demote_player", default: true
    t.boolean "logging_exec", default: true
    t.boolean "logging_gamble", default: true
    t.boolean "logging_modify_player", default: true
    t.boolean "logging_pay_territory", default: true
    t.boolean "logging_promote_player", default: true
    t.boolean "logging_remove_player_from_territory", default: true
    t.boolean "logging_reward_player", default: true
    t.boolean "logging_transfer_poptabs", default: true
    t.boolean "logging_upgrade_territory", default: true
    t.integer "max_payment_count", default: 0
    t.string "request_thread_type", default: "exile"
    t.float "request_thread_tick", default: 0.1
    t.integer "territory_payment_tax", default: 0
    t.integer "territory_upgrade_tax", default: 0
    t.integer "territory_price_per_object", default: 10
    t.integer "territory_lifetime", default: 7
    t.integer "server_restart_hour", default: 3
    t.integer "server_restart_min", default: 0
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_server_settings_on_deleted_at"
    t.index ["server_id"], name: "index_server_settings_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "server_id", null: false
    t.integer "community_id", null: false
    t.text "server_key"
    t.text "server_name"
    t.integer "server_visibility", default: 1, null: false
    t.string "server_ip"
    t.string "server_port"
    t.string "server_version"
    t.datetime "server_start_time"
    t.datetime "disconnected_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["server_id"], name: "index_servers_on_server_id", unique: true
    t.index ["server_key"], name: "index_servers_on_server_key", unique: true
    t.index ["uuid"], name: "index_servers_on_uuid", unique: true
  end

  create_table "territories", force: :cascade do |t|
    t.integer "server_id", null: false
    t.integer "territory_level", null: false
    t.bigint "territory_purchase_price", null: false
    t.integer "territory_radius", null: false
    t.integer "territory_object_count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_territories_on_deleted_at"
    t.index ["server_id"], name: "index_territories_on_server_id"
    t.index ["territory_level"], name: "index_territories_on_territory_level"
  end

  create_table "uploads", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "file", null: false
    t.string "file_name", null: false
    t.string "file_type", null: false
    t.integer "file_size", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_uploads_on_uuid"
  end

  create_table "user_gamble_stats", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "server_id", null: false
    t.integer "current_streak", default: 0, null: false
    t.integer "total_wins", default: 0, null: false
    t.integer "longest_win_streak", default: 0, null: false
    t.bigint "total_poptabs_won", default: 0, null: false
    t.bigint "total_poptabs_loss", default: 0, null: false
    t.integer "longest_loss_streak", default: 0, null: false
    t.integer "total_losses", default: 0, null: false
    t.string "last_action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id"], name: "index_user_gamble_stats_on_server_id"
    t.index ["user_id"], name: "index_user_gamble_stats_on_user_id"
  end

  create_table "user_notification_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "server_id", null: false
    t.boolean "base_raid", default: true, null: false
    t.boolean "charge_plant_started", default: true, null: false
    t.boolean "custom", default: true, null: false
    t.boolean "flag_restored", default: true, null: false
    t.boolean "flag_steal_started", default: true, null: false
    t.boolean "flag_stolen", default: true, null: false
    t.boolean "grind_started", default: true, null: false
    t.boolean "hack_started", default: true, null: false
    t.boolean "protection_money_due", default: true, null: false
    t.boolean "protection_money_paid", default: true, null: false
    t.boolean "marxet_item_sold", default: true, null: false
    t.index ["server_id"], name: "index_user_notification_preferences_on_server_id"
    t.index ["user_id"], name: "index_user_notification_preferences_on_user_id"
  end

  create_table "user_notification_routes", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "user_id", null: false
    t.integer "source_server_id"
    t.integer "destination_community_id", null: false
    t.string "channel_id", null: false
    t.string "notification_type", null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "user_accepted", default: false, null: false
    t.boolean "community_accepted", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["uuid"], name: "index_user_notification_routes_on_uuid"
  end

  create_table "user_steam_data", force: :cascade do |t|
    t.integer "user_id"
    t.string "username"
    t.text "avatar"
    t.text "profile_url"
    t.string "profile_visibility"
    t.datetime "profile_created_at"
    t.boolean "community_banned", default: false
    t.boolean "vac_banned", default: false
    t.integer "number_of_vac_bans", default: 0
    t.integer "days_since_last_ban", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "discord_id", null: false
    t.string "discord_username", null: false
    t.string "discord_discriminator", null: false
    t.text "discord_avatar"
    t.string "discord_access_token"
    t.string "discord_refresh_token"
    t.string "steam_uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discord_id"], name: "index_users_on_discord_id", unique: true
    t.index ["steam_uid"], name: "index_users_on_steam_uid"
  end

  add_foreign_key "command_configurations", "communities"
  add_foreign_key "log_entries", "logs"
  add_foreign_key "logs", "servers"
  add_foreign_key "requests", "users", column: "requestee_user_id"
  add_foreign_key "requests", "users", column: "requestor_user_id"
  add_foreign_key "server_mods", "servers"
  add_foreign_key "server_rewards", "servers"
  add_foreign_key "server_settings", "servers"
  add_foreign_key "servers", "communities"
  add_foreign_key "territories", "servers"
  add_foreign_key "user_gamble_stats", "servers"
  add_foreign_key "user_gamble_stats", "users"
  add_foreign_key "user_notification_preferences", "servers"
  add_foreign_key "user_notification_preferences", "users"
  add_foreign_key "user_notification_routes", "communities", column: "destination_community_id"
  add_foreign_key "user_notification_routes", "users"
  add_foreign_key "user_steam_data", "users"
end
