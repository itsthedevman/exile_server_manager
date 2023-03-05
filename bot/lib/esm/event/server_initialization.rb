# frozen_string_literal: true

module ESM
  module Event
    class ServerInitialization
      DATA_ATTRIBUTES = %i[
        community_id
        extdb_path
        gambling_modifier
        gambling_payout_base
        gambling_payout_randomizer_max
        gambling_payout_randomizer_mid
        gambling_payout_randomizer_min
        gambling_win_percentage
        logging_add_player_to_territory
        logging_channel_id
        logging_demote_player
        logging_exec
        logging_gamble
        logging_modify_player
        logging_pay_territory
        logging_promote_player
        logging_remove_player_from_territory
        logging_reward_player
        logging_transfer_poptabs
        logging_upgrade_territory
        max_payment_count
        server_id
        taxes_territory_payment
        taxes_territory_upgrade
        territory_admin_uids
        territory_lifetime
        territory_payment_tax
        territory_price_per_object
        territory_upgrade_tax
      ].freeze

      DATA = Struct.new(*DATA_ATTRIBUTES)

      attr_reader :data

      def initialize(connection, message)
        @message = message
        @connection = connection
        @server = connection.server
        @community = @server.community
        @discord_server = @community.discord_server
      end

      def run!
        # Updates the database with information from the server
        initialize_server

        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_setting_data

        # Send message to server
        send_response
      end

      # Called when an admin updates some settings.
      def update
        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_setting_data

        # Send message to server
        send_response
      end

      private

      def initialize_server
        update_server
        update_server_settings
        store_territory_data
        store_metadata
      end

      def update_server
        @server.update!(
          server_name: @message.data.server_name,
          server_start_time: @message.data.server_start_time.utc,
          server_version: @connection.version,
          disconnected_at: nil
        )
      end

      def update_server_settings
        @server.server_setting.update(
          territory_price_per_object: @message.data.price_per_object,
          territory_lifetime: @message.data.territory_lifetime
        )
      end

      def store_territory_data
        @server.territories.delete_all

        territories =
          @message.data.territory_data.map do |data|
            {
              server_id: @server.id,
              territory_level: data[:level],
              territory_purchase_price: data[:purchase_price],
              territory_radius: data[:radius],
              territory_object_count: data[:object_count]
            }
          end

        ESM::Territory.import(territories)
      end

      def store_metadata
        @server.metadata.vg_enabled = @message.data.vg_enabled
        @server.metadata.vg_max_sizes = @message.data.vg_max_sizes
      end

      def build_setting_data
        settings = @server.server_setting

        # Remove the database and v1 fields
        data = settings.attributes.without(
          *%w[
            id server_id created_at updated_at deleted_at
            server_restart_hour server_restart_min request_thread_type
            request_thread_tick logging_path
          ]
        ).symbolize_keys

        data = data.merge(
          community_id: @community.community_id,
          extdb_path: settings.extdb_path || "",
          logging_channel_id: @community.logging_channel_id,
          server_id: @server.server_id,
          territory_admin_uids: build_territory_admins,
          taxes_territory_payment: settings.territory_payment_tax / 100,
          taxes_territory_upgrade: settings.territory_upgrade_tax / 100
        )

        @data = DATA.new(*DATA_ATTRIBUTES.map { |attribute| data[attribute] })
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

      def send_response
        message = ESM::Message.event.set_data("post_init", @data)
        message.add_callback(:on_response) do |_incoming|
          # Trigger a connect notification
          ESM::Notifications.trigger("server_on_connect", server: @connection.server)

          # Set the connection to be available for commands
          @connection.initialized = true
        end

        @connection.send_message(message)
      end
    end
  end
end
