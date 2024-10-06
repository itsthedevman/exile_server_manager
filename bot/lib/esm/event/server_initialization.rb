# frozen_string_literal: true

module ESM
  module Event
    class ServerInitialization
      attr_reader :data

      def initialize(tcp_client, model, message)
        @tcp_client = tcp_client
        @model = model
        @message = message
        @community = @model.community
        @discord_server = @community.discord_server
      end

      def run!
        # Updates the database with information from the server
        initialize_server

        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_setting_data

        # Send message to server
        send_post_init
      end

      # Called when an admin updates some settings.
      def update
        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_setting_data

        # Send message to server
        send_post_init
      end

      private

      def initialize_server
        update_server
        update_server_settings
        store_territory_data
        store_metadata
      end

      def update_server
        @model.update!(
          server_name: @message.data.server_name,
          server_start_time: Time.parse(@message.data.server_start_time).utc,
          server_version: Semantic::Version.new(@message.data.extension_version),
          disconnected_at: nil
        )
      end

      def update_server_settings
        @model.server_setting.update(
          territory_price_per_object: @message.data.price_per_object,
          territory_lifetime: @message.data.territory_lifetime
        )
      end

      def store_territory_data
        @model.territories.delete_all

        territories =
          @message.data.territory_data.to_a.map do |data|
            data = ESM::Arma::HashMap.from(data).to_istruct

            {
              server_id: @model.id,
              territory_level: data.level,
              territory_purchase_price: data.purchase_price,
              territory_radius: data.radius,
              territory_object_count: data.object_count
            }
          end

        ESM::Territory.import(territories)
      end

      def store_metadata
        @tcp_client.set_metadata(
          vg_enabled: @message.data.vg_enabled,
          vg_max_sizes: @message.data.vg_max_sizes.to_a
        )
      end

      def build_setting_data
        settings = @model.server_setting

        # Remove the database and v1 fields
        data = settings.attributes.without(
          *%w[
            id server_id created_at updated_at deleted_at
            server_restart_hour server_restart_min request_thread_type
            request_thread_tick logging_path
          ]
        ).symbolize_keys

        @data = data.merge(
          function_name: "ESMs_system_process_postInit",
          community_id: @community.community_id,
          extdb_path: settings.extdb_path || "",
          logging_channel_id: @community.logging_channel_id,
          server_id: @model.server_id,
          territory_admin_uids: build_territory_admins,

          # Todo after v1: Fix the naming scheme on the database side
          logging_command_add: settings.logging_add_player_to_territory,
          logging_command_demote: settings.logging_demote_player,
          logging_command_gamble: settings.logging_gamble,
          logging_command_pay: settings.logging_pay_territory,
          logging_command_player: settings.logging_modify_player,
          logging_command_promote: settings.logging_promote_player,
          logging_command_remove: settings.logging_remove_player_from_territory,
          logging_command_reward: settings.logging_reward_player,
          logging_command_sqf: settings.logging_exec,
          logging_command_transfer: settings.logging_transfer_poptabs,
          logging_command_upgrade: settings.logging_upgrade_territory,
          taxes_territory_payment: settings.territory_payment_tax / 100,
          taxes_territory_upgrade: settings.territory_upgrade_tax / 100
        )
      end

      def build_territory_admins
        # Get all roles with administrator or that are set as territory admins
        roles = @discord_server.roles.select do |role|
          role.permissions.administrator || @community.territory_admin_ids.include?(role.id.to_s)
        end

        # Get all of the user's discord IDs who have these roles
        discord_ids =
          roles.map do |role|
            role.users.map { |user| user.id.to_s }
          end.flatten

        # Pluck all the steam UIDs we have, including the guild owners
        ESM::User.where(discord_id: discord_ids + [@discord_server.owner.id.to_s]).where.not(steam_uid: nil).pluck(:steam_uid)
      end

      def send_post_init
        message = ESM::Message.new
          .set_type(:post_init)
          .set_data(**@data)

        @tcp_client.send_message(message)

        info!(server_id: @model.server_id, uptime: @model.uptime)

        @model.community.log_event(
          :reconnect,
          I18n.t("server_connected", server: @model.server_id, uptime: @model.uptime)
        )
      end
    end
  end
end
