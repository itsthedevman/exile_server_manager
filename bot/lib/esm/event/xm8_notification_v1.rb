module ESM
  module Event
    class Xm8NotificationV1
      TYPES = %w[
        custom
        base-raid
        flag-stolen
        flag-restored
        flag-steal-started
        protection-money-due
        protection-money-paid
        grind-started
        hack-started
        charge-plant-started
        marxet-item-sold
      ].freeze

      # @param parameters [OpenStruct] The message from the server
      # @option id [String] The territory ID. Not available in `marxet-item-sold`, or `custom`
      # @option message [String, JSON] The name of the territory, not available in `marxet-item-sold`, or `custom`.
      #                                This value will be JSON for `marxet-item-sold` (`item`, `amount`), and `custom` (`title`, `body`)
      # @option type [String] The type of XM8 notification
      def initialize(server:, parameters:, connection: nil)
        @server = server
        @community = server.community

        # SteamUIDs
        @recipients = parameters.recipients.to_ostruct.r

        # Could be a string (territory_name) or JSON (item, amount, title, body)
        @message = parameters.message
        @xm8_type = parameters.type
        @territory_id = parameters.id

        # For generating notifications
        @attributes = {
          communityid: @community.community_id,
          serverid: @server.server_id,
          servername: @server.server_name,
          territoryid: @territory_id || "",
          territoryname: "",
          username: "",
          usertag: "",
          item: "",
          amount: ""
        }
      end

      def run!
        return if @recipients.blank?

        # Check for valid types
        check_for_valid_type!

        # Check for proper values
        case @xm8_type
        when "marxet-item-sold"
          @message = @message.to_ostruct
          check_for_invalid_marxet_attributes!

          @attributes[:amount] = @message.amount
          @attributes[:item] = @message.item
        when "custom"
          @message = @message.to_ostruct
          check_for_invalid_custom_attributes!
        else
          @attributes[:territoryname] = @message
        end

        # Determine with embed to send
        embed =
          if @xm8_type == "custom"
            custom_embed
          else
            notification_embed
          end

        # Convert the steam_uids in @recipients to users and send the notification
        @users = ESM::User.where(steam_uid: @recipients)
        @statuses_by_user = {}

        # Send the messages
        send_to_users(embed)
        send_to_custom_routes(embed)

        # Trigger a notification event
        ESM::Notifications.trigger(
          "xm8_notification_on_send",
          type: @xm8_type,
          server: @server,
          embed: embed,
          statuses: @statuses_by_user,
          unregistered_steam_uids: unregistered_steam_uids
        )

        @statuses_by_user
      rescue ESM::Exception::CheckFailure => e
        ESM::Notifications.trigger(e.data, server: @server, recipients: @recipients, message: @message, type: @xm8_type)
        raise ESM::Exception::Error if ESM.env.test?
      end

      # Returns the steam uids of the players who are not registered with ESM
      def unregistered_steam_uids
        steam_uids = @users.pluck(:steam_uid)

        @recipients.reject { |steam_uid| steam_uids.include?(steam_uid) }
      end

      private

      def check_for_valid_type!
        return if UserNotificationRoute::TYPES.include?(@xm8_type)

        raise ESM::Exception::CheckFailure, "xm8_notification_invalid_type"
      end

      def check_for_invalid_custom_attributes!
        return if @message.present? && (@message.title.present? || @message.body.present?)

        raise ESM::Exception::CheckFailure, "xm8_notification_invalid_attributes"
      end

      def check_for_invalid_marxet_attributes!
        return if @message.present? && @message.item.present? && @message.amount.present?

        raise ESM::Exception::CheckFailure, "xm8_notification_invalid_attributes"
      end

      def custom_embed
        # title or body can be nil but both cannot be empty
        ESM::Embed.build do |e|
          e.title = @message.title
          e.description = @message.body
          e.color = ESM::Color.random
          e.footer = "[#{@server.server_id}] #{@server.server_name}"
        end
      end

      def notification_embed
        embed = ESM::Notification.build_random(
          **@attributes.merge(community_id: @community.id, type: @xm8_type, category: "xm8")
        )
        embed.footer = "[#{@server.server_id}] #{@server.server_name}"
        embed
      end

      def send_to_users(embed)
        # Get the preferences for all the users we're supposed to send to
        dm_preferences_by_user_id = ESM::UserNotificationPreference.where(user_id: @users.pluck(:id)).pluck(:user_id, @xm8_type.underscore).to_h

        # Default the preference to allow. This is used for if the user hasn't ran the preference command before
        dm_preferences_by_user_id.default = true

        @users.each do |user|
          # For the logs later on
          @statuses_by_user[user] = status = {direct_message: :ignored, custom_routes: {sent: 0, expected: 0}}

          dm_allowed = dm_preferences_by_user_id[user.id]
          next unless dm_allowed

          pending_delivery = ESM.bot.deliver(embed, to: user.discord_user, async: false)
          message = pending_delivery&.wait_for_delivery
          status[:direct_message] = message.nil? ? :failure : :success
        end
      end

      def send_to_custom_routes(embed)
        # Custom routes are a little different.
        #   Using a mention in an embed does not cause a "notification" on discord. This does not work since these are often urgent.
        #   To get around this, routes need to be grouped by channel. From here, an initial message can be sent tagging each user with this channel (and type)
        users_by_channel_id = ESM::UserNotificationRoute.select(:user_id, :channel_id)
          .includes(:user)
          .enabled
          .accepted
          .where(notification_type: @xm8_type, user_id: @users.pluck(:id))
          .where("source_server_id IS NULL OR source_server_id = ?", @server.id)
          .group_by(&:channel_id)
          .transform_values! { |r| r.map(&:user) }

        users_by_channel_id.each do |channel_id, users|
          pending_delivery = ESM.bot.deliver(embed, to: channel_id, embed_message: "#{@xm8_type.titleize} - #{users.map(&:mention).join(" ")}", async: false)
          notification_message = pending_delivery&.wait_for_delivery

          users.each do |user|
            status = @statuses_by_user[user] ||= {direct_message: :ignored, custom_routes: {sent: 0, expected: 0}}

            status = status[:custom_routes]
            status[:sent] += 1 if notification_message
            status[:expected] += 1
          end
        end
      end
    end
  end
end
