# frozen_string_literal: true

module ESM
  module Event
    class SendXm8Notification
      def self.notification_manager
        @notification_manager ||= NotificationManager.new
      end

      def self.send_notifications(notifications)
        if notifications.any? { |n| !n.is_a?(Xm8Notification) }
          raise TypeError, "Invalid notifications provided: #{notifications}"
        end

        notification_manager.add(notifications)
      end

      attr_reader :server, :community, :message

      def initialize(server, message)
        @server = server
        @community = server.community
        @message = message
      end

      def run!
        notifications = filter_notifications
        return if notifications.blank?

        self.class.send_notifications(notifications)
      end

      private

      def filter_notifications
        notifications =
          filter_unregistered_recipients(message.data.notifications)

        notifications.filter_map do |notification|
          Xm8Notification.from(notification)
        rescue Xm8Notification::InvalidType
          notify_invalid_notification!(notification, :invalid_type)
        rescue Xm8Notification::InvalidContent
          notify_invalid_notification!(notification, :invalid_attributes)
        end
      end

      def filter_unregistered_recipients(notifications)
        recipient_steam_uids = notifications.map { |n| n[:recipient_uids] }
        uid_to_user_mapping = User.where(steam_uid: recipient_steam_uids)
          .to_h { |u| [u.steam_uid, u] }

        notifications_to_send = []
        notifications_to_reject = []

        notifications.each do |notification|
          recipient_notification_mapping = {}

          # These two attributes are index linked, meaning index 0 in both arrays are related
          recipients = notification[:recipient_uids].zip(notification[:uuids])

          # Remove any unregistered UIDs, and store the associated UUID
          recipients.each do |uid, uuid|
            user = uid_to_user_mapping[uid]
            next notifications_to_reject << uuid if user.nil?

            recipient_notification_mapping[user] = uuid
          end

          next if recipient_notification_mapping.blank?

          notification[:server] = server
          notification[:recipient_notification_mapping] = recipient_notification_mapping

          notifications_to_send << notification.without(:recipient_uids, :uuids)
        end

        # Update the server's database to stop sending these
        if notifications_to_reject.size > 0
          update_unregistered_notifications(notifications_to_reject)
        end

        notifications_to_send
      end

      def notify_invalid_notification!(notification, type)
        error = [
          I18n.t(
            "xm8_notifications.#{type}.title",
            server: server.server_id
          ),
          I18n.t(
            "xm8_notifications.#{type}.description",
            type: notification[:type]
          ),
          I18n.t(:xm8_notification),
          JSON.pretty_generate(notification[:content])
        ]

        server.log_error(error.join("\n"))
      end

      def update_unregistered_notifications(unregistered_notifications)
        status_update = unregistered_notifications.to_h do |uuid|
          [uuid, Xm8Notification.failed_state(Xm8Notification::DETAILS_NOT_REGISTERED)]
        end

        message = ESM::Message.new
          .set_type(:query)
          .set_data(
            query_function_name: "update_xm8_notification_state",
            **status_update
          )

        server.send_message(message, block: false)
      end
    end
  end
end
