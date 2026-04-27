# frozen_string_literal: true

class InitialDb < ActiveRecord::Migration[5.2]
  def change
    enable_extension "hstore" unless extension_enabled?("hstore")
    enable_extension "uuid-ossp" unless extension_enabled?("uuid-ossp")

    # Attributes for ESM
    create_table :bot_attributes do |t|
      t.boolean :maintenance_mode_enabled, null: false, default: false
      t.string :maintenance_message, null: true
      t.string :status_type, null: false, default: "PLAYING"
      t.string :status_message, null: true
      t.integer :community_count, default: 0
      t.integer :server_count, default: 0
      t.integer :user_count, default: 0
    end

    # communities
    create_table :communities do |t|
      t.string :community_id, null: false # has unique index
      t.text :community_name
      t.string :guild_id, null: false # has unique index
      t.string :logging_channel_id
      t.boolean :log_reconnect_event, default: false
      t.boolean :log_xm8_event, default: true
      t.boolean :log_discord_log_event, default: true
      t.boolean :player_mode_enabled, default: true
      t.json :territory_admin_ids, default: []
      t.string :command_prefix, default: nil
      t.boolean :welcome_message_enabled, default: true
      t.text :welcome_message, default: ""
      t.timestamps
      t.datetime :deleted_at, index: true
    end

    # command_configurations
    create_table :command_configurations do |t|
      t.integer :community_id, null: false, index: true
      t.string :command_name, null: false, index: true
      t.boolean :enabled, default: true
      t.boolean :notify_when_disabled, default: true
      t.integer :cooldown_quantity, default: 2
      t.string :cooldown_type, default: "seconds"
      t.boolean :allowed_in_text_channels, default: true
      t.boolean :whitelist_enabled, default: false
      t.json :whitelisted_role_ids, default: []
      t.timestamps
      t.datetime :deleted_at, index: true
    end

    # Command usage counts
    create_table :command_counts do |t|
      t.string :command_name, null: false, index: true
      t.integer :execution_count, null: false, default: 0
    end

    # Command Cache
    create_table :command_caches do |t|
      t.string :command_name, index: true
      t.string :command_type
      t.string :command_category
      t.text :command_description
      t.text :command_example
      t.text :command_usage
      t.text :command_arguments
      t.json :command_aliases
      t.json :command_defines
    end

    # cooldowns
    create_table :cooldowns do |t|
      t.string :command_name
      t.integer :community_id
      t.integer :server_id
      t.integer :user_id
      t.string :steam_uid
      t.integer :cooldown_quantity
      t.string :cooldown_type
      t.integer :cooldown_amount, default: 0
      t.datetime :expires_at
      t.timestamps
    end

    # Downloads
    create_table :downloads do |t|
      t.uuid :uuid, unique: true, null: false
      t.string :version, unique: true, null: false
      t.string :file
      t.boolean :current_release
      t.timestamps
    end

    # logs
    create_table :logs do |t|
      t.uuid :uuid, null: false
      t.integer :server_id, null: false, index: true
      t.text :search_text
      t.string :requestors_user_id
      t.datetime :expires_at, index: true
      t.timestamps
    end

    # log_entries
    create_table :log_entries do |t|
      t.integer :log_id, null: false, index: true
      t.datetime :log_date, null: false
      t.string :file_name, null: false
      t.json :entries
    end

    # notifications
    create_table :notifications do |t|
      t.integer :community_id, null: false, index: true
      t.string :notification_type, null: false
      t.text :notification_title
      t.text :notification_description
      t.string :notification_color
      t.string :notification_category
      t.timestamps
    end

    # requests
    create_table :requests do |t|
      t.uuid :uuid, index: true
      t.string :uuid_short
      t.integer :requestor_user_id
      t.integer :requestee_user_id
      t.string :requested_from_channel_id, null: false
      t.string :command_name, null: false
      t.json :command_arguments, default: nil
      t.datetime :expires_at, index: true
      t.timestamps
    end

    # servers
    create_table :servers do |t|
      t.string :server_id, null: false
      t.integer :community_id, null: false, index: true
      t.text :server_name
      t.text :server_key, null: true
      t.string :server_ip
      t.string :server_port
      t.datetime :server_start_time
      t.datetime :disconnected_at
      t.timestamps
      t.datetime :deleted_at, index: true
    end

    # server_mods
    create_table :server_mods do |t|
      t.integer :server_id, null: false, index: true
      t.text :mod_name, null: false
      t.text :mod_link, default: nil
      t.string :mod_version, default: nil
      t.boolean :mod_required, null: false, default: false
      t.timestamps
      t.datetime :deleted_at, index: true
    end

    # server_rewards
    create_table :server_rewards do |t|
      t.integer :server_id, index: true, null: false
      t.json :reward_items, default: {}
      t.bigint :player_poptabs, default: 0
      t.bigint :locker_poptabs, default: 0
      t.bigint :respect, default: 0
      t.datetime :deleted_at, index: true
    end

    # server_settings
    create_table :server_settings do |t|
      t.integer :server_id, index: true
      t.text :extdb_path, default: nil
      t.integer :gambling_payout, default: 95
      t.integer :gambling_modifier, default: 1
      t.float :gambling_randomizer_min, default: 0
      t.float :gambling_randomizer_mid, default: 0.5
      t.float :gambling_randomizer_max, default: 1
      t.integer :gambling_win_chance, default: 35
      t.text :logging_path, default: nil
      t.boolean :logging_add_player_to_territory, default: true
      t.boolean :logging_demote_player, default: true
      t.boolean :logging_exec, default: true
      t.boolean :logging_gamble, default: true
      t.boolean :logging_modify_player, default: true
      t.boolean :logging_pay_territory, default: true
      t.boolean :logging_promote_player, default: true
      t.boolean :logging_remove_player_from_territory, default: true
      t.boolean :logging_reward, default: true
      t.boolean :logging_transfer, default: true
      t.boolean :logging_upgrade_territory, default: true
      t.integer :max_payment_count, default: 0
      t.string :request_thread_type, default: "exile"
      t.float :request_thread_tick, default: 0.1
      t.integer :territory_payment_tax, default: 0
      t.integer :territory_upgrade_tax, default: 0
      t.integer :territory_price_per_object, default: 10
      t.integer :territory_lifetime, default: 7
      t.integer :server_restart_hour, default: 3
      t.integer :server_restart_min, default: 0
      t.datetime :deleted_at, index: true
    end

    # territories
    create_table :territories do |t|
      t.integer :server_id, null: false, index: true
      t.integer :territory_level, null: false, index: true
      t.bigint :territory_purchase_price, null: false
      t.integer :territory_radius, null: false
      t.integer :territory_object_count, null: false
      t.timestamps
      t.datetime :deleted_at, index: true
    end

    # uploads
    create_table :uploads do |t|
      t.uuid :uuid, null: false, index: true
      t.string :file, null: false
      t.string :file_name, null: false
      t.string :file_type, null: false
      t.integer :file_size, null: false
      t.timestamps
    end

    # users
    create_table :users do |t|
      t.string :discord_id, null: false
      t.string :discord_username, null: false
      t.string :discord_discriminator, null: false
      t.text :discord_avatar, default: nil
      t.string :discord_access_token, default: nil
      t.string :discord_refresh_token, default: nil
      t.string :steam_uid, default: nil, index: true
      t.timestamps
    end

    # user_steam_data
    create_table :user_steam_data do |t|
      t.integer :user_id
      t.string :username, default: nil
      t.text :avatar, default: nil
      t.text :profile_url, default: nil
      t.string :profile_visibility, default: nil
      t.datetime :profile_created_at, default: nil
      t.boolean :community_banned, default: false
      t.boolean :vac_banned, default: false
      t.integer :number_of_vac_bans, default: 0
      t.integer :days_since_last_ban, default: 0
      t.timestamps
    end

    # user_gambling_stats
    create_table :user_gamble_stats do |t|
      t.integer :user_id, null: false, index: true
      t.integer :server_id, null: false, index: true
      t.integer :current_streak, null: false, default: 0
      t.integer :total_wins, null: false, default: 0
      t.integer :longest_win_streak, null: false, default: 0
      t.bigint :total_poptabs_won, null: false, default: 0
      t.bigint :total_poptabs_loss, null: false, default: 0
      t.integer :longest_loss_streak, null: false, default: 0
      t.integer :total_losses, null: false, default: 0
      t.string :last_action, default: nil
      t.timestamps
    end

    # user_notification_preferences
    create_table :user_notification_preferences do |t|
      t.integer :user_id, null: false, index: true
      t.integer :server_id, null: false, index: true
      t.boolean :base_raid, null: false, default: true
      t.boolean :charge_plant_started, null: false, default: true
      t.boolean :custom, null: false, default: true
      t.boolean :flag_restored, null: false, default: true
      t.boolean :flag_steal_started, null: false, default: true
      t.boolean :flag_stolen, null: false, default: true
      t.boolean :grind_started, null: false, default: true
      t.boolean :hack_started, null: false, default: true
      t.boolean :protection_money_due, null: false, default: true
      t.boolean :protection_money_paid, null: false, default: true
      t.boolean :marxet_item_sold, null: false, default: true
    end

    add_index :communities, :community_id, unique: true
    add_index :communities, :guild_id, unique: true
    add_index :cooldowns, %i[command_name user_id community_id]
    add_index :cooldowns, %i[command_name steam_uid community_id]
    add_index :downloads, :current_release
    add_index :logs, :uuid, unique: true
    add_index :log_entries, [:log_id, :log_date]
    add_index :log_entries, [:log_id, :log_date, :file_name]
    add_index :servers, :server_id, unique: true
    add_index :servers, :server_key, unique: true
    add_index :users, :discord_id, unique: true
    add_index :requests, %i[requestee_user_id uuid_short], unique: true

    add_foreign_key :command_configurations, :communities
    add_foreign_key :logs, :servers
    add_foreign_key :log_entries, :logs
    add_foreign_key :requests, :users, column: :requestor_user_id
    add_foreign_key :requests, :users, column: :requestee_user_id
    add_foreign_key :servers, :communities
    add_foreign_key :server_mods, :servers
    add_foreign_key :server_rewards, :servers
    add_foreign_key :server_settings, :servers
    add_foreign_key :territories, :servers
    add_foreign_key :user_steam_data, :users
    add_foreign_key :user_gamble_stats, :users
    add_foreign_key :user_gamble_stats, :servers
    add_foreign_key :user_notification_preferences, :users
    add_foreign_key :user_notification_preferences, :servers
  end
end
