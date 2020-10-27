module ESM
  module Event
    class Xm8Notification
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
      def initialize(connection:, server:, parameters:)
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
        @users.each do |user|
          ESM.bot.deliver(embed, to: user.discord_user)

          # Anti-ratelimit
          sleep(0.5)
        end

        # Trigger a notification event
        ESM::Notifications.trigger(
          "xm8_notification_on_send",
          type: @xm8_type,
          server: @server,
          embed: embed,
          sent_to_users: @users,
          unregistered_steam_uids: unregistered_steam_uids
        )
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
        return if TYPES.include?(@xm8_type)

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
        end
      end

      def notification_embed
        ESM::Notification.build_random(@attributes.merge(community_id: @community.id, type: @xm8_type, category: "xm8"))
      end
    end
  end
end
