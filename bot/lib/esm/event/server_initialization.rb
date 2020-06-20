# frozen_string_literal: true

module ESM
  module Event
    class ServerInitialization
      attr_reader :packet if ESM.env.test?

      def initialize(server, params)
        @server = server
        @params = params
      end

      def run!
        # Updates the database with information from the server
        initialize_server!

        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_settings_packet

        # Send packet to server
        send_response
      end

      private

      def initialize_server!
        update_server!
        update_server_settings!
        store_territory_info!

        @community = @server.community
        @guild = ESM.bot.server(@community.guild_id)
      end

      def update_server!
        @server.update!(
          server_name: @params.server_name,
          server_start_time: DateTime.parse(@params.server_start_time),
          disconnected_at: nil
        )
      end

      def update_server_settings!
        @server.server_setting.update(
          territory_price_per_object: @params.price_per_object,
          territory_lifetime: @params.territory_lifetime,
          server_restart_hour: @params.server_restart.first,
          server_restart_min: @params.server_restart.second
        )
      end

      def store_territory_info!
        ESM::Territory.all.in_batches(of: 10_000).delete_all

        # All territory info is prefixed with `territory_level_`
        territory_info = @params.to_h.select { |key, _| key.to_s.starts_with?("territory_level_") }
        territories =
          territory_info.map do |_, info|
            {
              server_id: @server.id,
              territory_level: info[:level],
              territory_purchase_price: info[:purchase_price],
              territory_radius: info[:radius],
              territory_object_count: info[:object_count]
            }
          end

        ESM::Territory.import(territories)
      end

      def build_settings_packet
        settings = @server.server_setting
        rewards = @server.server_reward

        @packet = OpenStruct.new(
          function_name: "postServerInitialization",
          server_id: @server.server_id,
          territory_admins: build_territory_admins.to_json,
          extdb_path: settings.extdb_path || "",
          gambling_modifier: settings.gambling_modifier,
          gambling_payout: settings.gambling_payout,
          gambling_randomizer_max: settings.gambling_randomizer_max,
          gambling_randomizer_mid: settings.gambling_randomizer_mid,
          gambling_randomizer_min: settings.gambling_randomizer_min,
          gambling_win_chance: settings.gambling_win_chance,
          logging_add_player_to_territory: settings.logging_add_player_to_territory,
          logging_demote_player: settings.logging_demote_player,
          logging_exec: settings.logging_exec,
          logging_gamble: settings.logging_gamble,
          logging_modify_player: settings.logging_modify_player,
          logging_pay_territory: settings.logging_pay_territory,
          logging_promote_player: settings.logging_promote_player,
          logging_remove_player_from_territory: settings.logging_remove_player_from_territory,
          logging_reward: settings.logging_reward,
          logging_transfer: settings.logging_transfer,
          logging_upgrade_territory: settings.logging_upgrade_territory,
          logging_path: settings.logging_path || "",
          max_payment_count: settings.max_payment_count,
          request_thread_tick: settings.request_thread_tick,
          request_thread_type: settings.request_thread_type == "exile",
          taxes_territory_payment: settings.territory_payment_tax / 100,
          taxes_territory_upgrade: settings.territory_upgrade_tax / 100,
          reward_player_poptabs: rewards.player_poptabs,
          reward_locker_poptabs: rewards.locker_poptabs,
          reward_respect: rewards.respect,
          reward_items: rewards.reward_items.to_a.to_json,
          is_premium: true # Needed for legacy v1.0 support
        )
      end

      def build_territory_admins
        # Get all roles with administrator or that are set as territory admins
        roles = @guild.roles.select { |role| role.permissions.administrator || @community.territory_admin_ids.include?(role.id.to_s) }

        # Get all of the user's discord IDs who have these roles
        discord_ids =
          roles.map do |role|
            role.users.map { |user| user.id.to_s }
          end.flatten

        # Pluck all the steam UIDs we have, including the guild owners
        ESM::User.where(discord_id: discord_ids + [@guild.owner.id.to_s]).pluck(:steam_uid)
      end

      def send_response
        # Build the request
        request = ESM::Websocket::Request.new(command_name: "post_initialization", parameters: @packet.to_h)

        # Send it to the dll
        ESM::Websocket.deliver!(@server.server_id, request)
      end
    end
  end
end
