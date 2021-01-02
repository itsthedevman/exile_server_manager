# frozen_string_literal: true
# Migrate the pre 2.0.0 data to the 2.0.0 database

require 'rethinkdb'
include RethinkDB::Shortcuts

class MigrateDatabase
  class << self
    def run
      @db_connection = connect_to_rethinkdb

      puts "Starting Migration"
      # Not moving
      # logs (servers, users)
      # commands
      # uploads
      # requests
      # downloads
      ### ORDER MATTERS
      # bots
      move_bots

      # communities
      # pledges (communities)
      # command_configuration (communities)
      move_communities

      # servers (communities)
      # server_mods (servers)
      # server_rewards (servers)
      # server_settings (servers)
      # territories (servers)
      move_servers

      # users
      # user_gambling (servers, users)
      # user_notification_preferences (servers, users)
      move_users

      # cooldowns (communities, servers, users)
      # downloads
      # requests
      move_cooldowns

      # notifications (communities)
      move_notifications

      puts "Migration Finished"
      nil
    end

    def delete
      ESM::Request.all.delete_all
      ESM::BotAttribute.all.delete_all
      ESM::ServerMod.all.delete_all
      ESM::ServerReward.all.delete_all
      ESM::ServerSetting.all.delete_all
      ESM::Territory.all.delete_all
      ESM::Cooldown.all.delete_all
      ESM::UserSteamData.all.delete_all
      ESM::UserGambleStat.all.delete_all
      ESM::UserNotificationPreference.all.delete_all
      ESM::Notification.all.delete_all
      ESM::Server.all.delete_all
      ESM::CommandConfiguration.all.delete_all
      ESM::Community.all.delete_all
      ESM::User.all.delete_all
    end

    private

    def move_bots
      print "Migrating bot_attributes..."
      query("bots") do |bot|
        ESM::BotAttribute.create!(
          maintenance_mode_enabled: bot.maintenance_mode,
          maintenance_message: bot.maintenance_message,
          status_type: bot.status_type,
          status_message: bot.status_message
        )
      end
      puts "done"
    end

    def move_communities
      print "Migrating communities..."
      query("communities") do |community|
        community_name =
          if community.name.present?
            community.name
          else
            discord_server = ESM.bot.server(community.guild_id)
            discord_server&.name || "Discord Community"
          end


        # Create the community
        new_community = ESM::Community.create!(
          community_id: community.id,
          community_name: community_name,
          guild_id: community.guild_id,
          logging_channel_id: community.logging_channel,
          log_reconnect_event: community.reconnect_notif || true,
          log_xm8_event: community.log_xm8_notifications || true,
          player_mode_enabled: community.player_mode_enabled,
          territory_admin_ids: (community.territory_admin.keys rescue []),
          command_prefix: "!"
        )

        # Create it's command_configurations
        move_command_configuration(community, new_community)
      end
      puts "done"
    end

    def move_command_configuration(old_community, new_community)
      return if old_community.command_configuration.blank?

      old_community.command_configuration.each_pair do |key, value|
        ESM::CommandConfiguration.create!(
          community_id: new_community.id,
          command_name: key,
          enabled: value.enabled || true,
          notify_when_disabled: true,
          cooldown_quantity: (value.cooldown[0] rescue "2"),
          cooldown_type: (value.cooldown[1] rescue "seconds"),
          allowed_in_text_channels: value.allowed_in_text_channels || true,
          whitelist_enabled: value.permissions.present?,
          whitelisted_role_ids: value.permissions || []
        )
      end
    end

    def move_servers
      print "Migrating servers..."
      query("servers") do |server|
        community = ESM::Community.find_by_community_id(server.community_id)
        next if community.nil?

        new_server = ESM::Server.create!(
          server_id: server.id,
          community_id: community.id,
          server_name: server.name.presence || nil,
          server_key: server.key,
          server_ip: server.ip,
          server_port: server.port,
          server_start_time: server.start_time,
          created_at: server.created_at
        )

        # Server Mods
        move_server_mods(server, new_server)

        # Server Rewards
        move_server_rewards(server, new_server)

        # Server Settings
        move_server_settings(server, new_server)

        # Territories
        move_territories(new_server)
      end
      puts "done"
    end

    def move_server_mods(old_server, new_server)
      old_server.mods.each_pair do |mod_name, mod_attributes|
        ESM::ServerMod.create!(
          server_id: new_server.id,
          mod_name: mod_name,
          mod_link: mod_attributes.link.presence || nil,
          mod_version: mod_attributes.version.presence || nil,
          mod_required: mod_attributes.required
        )
      end
    end

    def move_server_rewards(old_server, new_server)
      rewards = old_server.rewards
      reward = ESM::ServerReward.where(server_id: new_server.id).first_or_create
      reward.update!(
        reward_items: rewards.items.to_h,
        player_poptabs: rewards.player_poptabs,
        locker_poptabs: rewards.locker_poptabs,
        respect: rewards.respect
      )
    end

    def move_server_settings(old_server, new_server)
      settings = old_server.settings
      setting = ESM::ServerSetting.where(server_id: new_server.id).first_or_create
      setting.update!(
        server_id: new_server.id,
        extdb_path: !settings.extdb_path.blank? ? settings.extdb_path : nil,
        gambling_payout: settings.gambling.payout,
        gambling_modifier: settings.gambling.modifier,
        gambling_randomizer_min: settings.gambling.randomizer.min,
        gambling_randomizer_mid: settings.gambling.randomizer.mid,
        gambling_randomizer_max: settings.gambling.randomizer.max,
        gambling_win_chance: settings.gambling.win_chance,
        logging_path: !settings.logging_path.blank? ? settings.logging_path : nil,
        logging_add_player_to_territory: settings.logging.add_player_to_territory,
        logging_demote_player: settings.logging.demote_player,
        logging_exec: settings.logging.exec,
        logging_gamble: settings.logging.gamble,
        logging_modify_player: settings.logging.modify_player,
        logging_pay_territory: settings.logging.pay_territory,
        logging_promote_player: settings.logging.promote_player,
        logging_remove_player_from_territory: settings.logging.remove_player_from_territory,
        logging_reward: settings.logging.reward,
        logging_transfer: settings.logging.transfer,
        logging_upgrade_territory: settings.logging.upgrade_territory,
        max_payment_count: settings.max_payment_count,
        request_thread_type: settings.request_thread.type,
        request_thread_tick: settings.request_thread.tick,
        territory_payment_tax: settings.taxes.territory_payment,
        territory_upgrade_tax: settings.taxes.territory_upgrade,
        territory_price_per_object: old_server.price_per_object,
        territory_lifetime: old_server.territory_lifetime,
        server_restart_hour: old_server.restart_hour,
        server_restart_min: old_server.restart_min
      )
    end

    def move_territories(new_server)
      query("territories", server_id: new_server.server_id) do |territory|
        ESM::Territory.create!(
          server_id: new_server.id,
          territory_level: territory.level,
          territory_purchase_price: territory.purchase_price,
          territory_radius: territory.radius,
          territory_object_count: territory.object_count
        )
      rescue StandardError => e
        puts e
      end
    end

    def move_users
      print "Migrating users..."
      query("users") do |user|
        next if user.id.blank?

        new_user = ESM::User.create!(
          discord_id: user.id,
          discord_username: user.name || "Discord User",
          discord_discriminator: user.discriminator || "#0001",
          discord_avatar: user.avatar,
          discord_access_token: user.token,
          discord_refresh_token: user.refresh_token,
          steam_uid: user.steam_uid.presence || nil,
          created_at: user.created_at
        )

        # user_gambling
        move_user_gambling(user, new_user)

        # user_notification_preferences
        move_user_notification_preferences(user, new_user)
      end
      puts "done"
    end

    def move_user_gambling(old_user, new_user)
      return if old_user.gambling.blank?

      old_user.gambling.each_pair do |server_id, gambling_info|
        server = ESM::Server.find_by_server_id(server_id)
        next if server.nil?

        last_action =
          if gambling_info[:last_action] == "win"
            "won"
          else
            "loss"
          end

        ESM::UserGambleStat.create!(
          user_id: new_user.id,
          server_id: server.id,
          current_streak: gambling_info[:current_streak],
          total_wins: gambling_info[:wins],
          longest_win_streak: gambling_info[:win_streak],
          total_poptabs_won: gambling_info[:won_poptabs],
          total_poptabs_loss: gambling_info[:loss_poptabs],
          longest_loss_streak: gambling_info[:loss_streak],
          total_losses: gambling_info[:loss],
          last_action: last_action
        )
      end
    end

    def move_user_notification_preferences(old_user, new_user)
      return if old_user.preferences.blank?

      old_user.preferences.each_pair do |server_id, preferences|
        server = ESM::Server.find_by_server_id(server_id)
        next if server.nil?

        ESM::UserNotificationPreference.create!(
          user_id: new_user.id,
          server_id: server.id,
          custom: preferences[:"custom"] || true,
          base_raid: preferences[:"base-raid"] || true,
          flag_stolen: preferences[:"flag-stolen"] || true,
          flag_restored: preferences[:"flag-restored"] || true,
          flag_steal_started: preferences[:"flag-steal-started"] || true,
          protection_money_due: preferences[:"protection-money-due"] || true,
          protection_money_paid: preferences[:"protection-money-paid"] || true,
          grind_started: preferences[:"grind-started"] || true,
          hack_started: preferences[:"hack-started"] || true,
          charge_plant_started: preferences[:"charge-plant-started"] || true,
          marxet_item_sold: preferences[:"marxet-item-sold"] || true
        )
      end
    end

    def move_cooldowns
      print "Migrating cooldowns..."
      query("cooldowns") do |cooldown|
        community = ESM::Community.find_by_community_id(cooldown.community_id)
        server = ESM::Server.find_by_server_id(cooldown.server_id)
        user = ESM::User.find_by_discord_id(cooldown.user_id)

        if user.nil?
          user = ESM::User.find_by_steam_uid(cooldown.steam_uid)
          next if user.nil?
        end

        ESM::Cooldown.create!(
          community_id: community.nil? ? nil : community.id,
          server_id: server.nil? ? nil : server.id,
          user_id: user.id,
          steam_uid: cooldown.steam_uid.presence || nil,
          command_name: cooldown.command_name,
          cooldown_quantity: cooldown.quantity,
          cooldown_type: cooldown.type,
          cooldown_amount: cooldown.amount,
          expires_at: cooldown.expires_at
        )
      end
      puts "done"
    end

    def move_notifications
      print "Migrating notifications..."
      query("notifications") do |notification|
        community = ESM::Community.find_by_community_id(notification.community_id)
        next if community.nil?

        notification_type =
          if notification.type == "win"
            "won"
          else
            notification.type
          end

        ESM::Notification.create!(
          community_id: community.id,
          notification_type: notification_type,
          notification_title: notification.title,
          notification_description: notification.message,
          notification_color: notification.color,
          notification_category: notification.category,
          created_at: notification.created_at
        )
      end
      puts "done"
    end

    private

    def connect_to_rethinkdb
      r.connect(host: "localhost", port: 28015, db: "exile_server_manager")
    end

    def query(table_name, **sub_query, &block)
      values = []

      if sub_query.blank?
        values = r.table(table_name).run(@db_connection)
      else
        values = r.table(table_name).filter(sub_query).run(@db_connection)
      end

      values.each do |value|
        yield(JSON.parse(value.to_json, object_class: OpenStruct))
      end
    end
  end
end

task migrate_rethinkdb: :environment do
  MigrateDatabase.run
end
