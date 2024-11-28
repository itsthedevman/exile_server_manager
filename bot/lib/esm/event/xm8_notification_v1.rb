# frozen_string_literal: true

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

        notify_on_send!(embed)
        @statuses_by_user
      rescue ESM::Exception::CheckFailure => e
        send(e.data) # notify_invalid_type!, notify_invalid_attributes!
        raise ESM::Exception::Error if ESM.env.test?
      end

      # Returns the steam uids of the players who are not registered with ESM
      def unregistered_steam_uids
        @unregistered_steam_uids ||= begin
          steam_uids = @users.pluck(:steam_uid)
          @recipients.reject { |steam_uid| steam_uids.include?(steam_uid) }
        end
      end

      private

      def check_for_valid_type!
        return if UserNotificationRoute::TYPES.include?(@xm8_type)

        raise ESM::Exception::CheckFailure, :notify_invalid_type!
      end

      def check_for_invalid_custom_attributes!
        return if @message.present? && (@message.title.present? || @message.body.present?)

        raise ESM::Exception::CheckFailure, :notify_invalid_attributes!
      end

      def check_for_invalid_marxet_attributes!
        return if @message.present? && @message.item.present? && @message.amount.present?

        raise ESM::Exception::CheckFailure, :notify_invalid_attributes!
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

          message = ESM.bot.deliver(embed, to: user.discord_user, block: true)
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
          notification_message = ESM.bot.deliver(embed, to: channel_id, embed_message: "#{@xm8_type.titleize} - #{users.map(&:mention).join(" ")}", block: true)

          users.each do |user|
            status = @statuses_by_user[user] ||= {direct_message: :ignored, custom_routes: {sent: 0, expected: 0}}

            status = status[:custom_routes]
            status[:sent] += 1 if notification_message
            status[:expected] += 1
          end
        end
      end

      def notify_invalid_type!
        embed =
          ESM::Embed.build do |e|
            e.title = I18n.t("xm8_notifications.invalid_type.title", server: @server.server_id)
            e.description = I18n.t("xm8_notifications.invalid_type.description", type: @xm8_type)

            e.add_field(name: I18n.t(:message), value: "```#{@message}```")
            e.add_field(name: I18n.t("xm8_notifications.recipient_steam_uids"), value: "```#{@recipients.join("\n")}```")

            e.color = :red
            e.footer = I18n.t("xm8_notifications.footer")
          end

        @server.community.log_event(:xm8, embed)
      end

      def notify_invalid_attributes!
        case @xm8_type
        when "custom"
          error = I18n.t("xm8_notifications.v1.invalid_attributes.custom.error")
          remedy = I18n.t("xm8_notifications.v1.invalid_attributes.custom.remedy")
        when "marxet-item-sold"
          error = I18n.t("xm8_notifications.v1.invalid_attributes.marxet_item_sold.error")
          remedy = I18n.t("xm8_notifications.v1.invalid_attributes.marxet_item_sold.remedy")
        end

        embed =
          ESM::Embed.build do |e|
            e.title = I18n.t("xm8_notifications.v1.invalid_attributes.title", server: @server.server_id)
            e.description = I18n.t("xm8_notifications.v1.invalid_attributes.description", error: error, remedy: remedy) if error && remedy

            log_message = I18n.t("xm8_notifications.v1.invalid_attributes.log_message.base")
            log_message += I18n.t("xm8_notifications.v1.invalid_attributes.log_message.title", title: @message.title) if @message.title.present?
            log_message += I18n.t("xm8_notifications.v1.invalid_attributes.log_message.title", message: @message.description) if @message.description.present?

            e.add_field(name: I18n.t(:message), value: log_message)
            e.add_field(name: I18n.t("xm8_notifications.recipient_steam_uids"), value: "```#{@recipients.join("\n")}```")

            e.color = :red
            e.footer = I18n.t("xm8_notifications.footer")
          end

        @server.community.log_event(:xm8, embed)
      end

      # type: @xm8_type,
      # server: @server,
      # embed: embed,
      # statuses: @statuses_by_user,
      # unregistered_steam_uids: unregistered_steam_uids
      def notify_on_send!(notification)
        message_statuses =
          @statuses_by_user.map do |user, hash|
            # { direct_message: :ignored, custom_routes: { sent: 0, expected: 0 } }
            direct_message = hash[:direct_message]
            custom_routes =
              case hash[:custom_routes]
              when ->(v) { v[:sent].zero? && v[:expected].zero? }
                :none
              when ->(v) { v[:expected].positive? && v[:sent] == v[:expected] }
                :success
              else
                :failure
              end

            direct_message_status = I18n.t(
              "xm8_notifications.v1.log.message_statuses.values.direct_message.#{direct_message}",
              user: user.discord_username,
              steam_uid: user.steam_uid
            )

            custom_route_status = I18n.t(
              "xm8_notifications.v1.log.message_statuses.values.custom_routes.#{custom_routes}",
              number_sent: hash[:custom_routes][:sent],
              number_expected: hash[:custom_routes][:expected]
            )

            status = "**#{user.distinct}** (`#{user.steam_uid}`)\n **-** #{direct_message_status}"
            status += "\n **-** #{custom_route_status}" if custom_route_status.present?
            status
          end

        # For debugging
        info!(
          type: @xm8_type,
          server: @server.server_id,
          notification: notification.to_h,
          message_statuses: message_statuses,
          unregistered_steam_uids: unregistered_steam_uids,
          log: @server.community.log_xm8_event?
        )

        # Notify the community if they subscribe to this notification
        embed =
          ESM::Embed.build do |e|
            e.title = I18n.t("xm8_notifications.v1.log.title", type: @xm8_type, server: @server.server_id)
            e.description = I18n.t("xm8_notifications.v1.log.description", title: notification.title, description: notification.description)

            if message_statuses.present?
              e.add_field(
                name: I18n.t("xm8_notifications.v1.log.message_statuses.name"),
                value: message_statuses.join("\n\n")
              )
            end

            if unregistered_steam_uids.present?
              e.add_field(
                name: I18n.t("xm8_notifications.v1.log.unregistered_steam_uids"),
                value: unregistered_steam_uids
              )
            end

            e.color = ESM::Color.random
            e.footer = I18n.t("xm8_notifications.footer")
          end

        @server.community&.log_event(:xm8, embed)
      end
    end
  end
end
