# frozen_string_literal: true

module ESM
  attributes = %i[id recipient_notification_mapping server content created_at]

  class Xm8Notification < Struct.new(*attributes)
    TYPES = {
      "base-raid": BaseRaid,
      "charge-plant-started": ChargePlantStarted,
      custom: Custom,
      "flag-restored": FlagRestored,
      "flag-steal-started": FlagStealStarted,
      "flag-stolen": FlagStolen,
      "grind-started": GrindStarted,
      "hack-started": HackStarted,
      "marxet-item-sold": MarxetItemSold,
      "protection-money-due": ProtectionMoneyDue,
      "protection-money-paid": ProtectionMoneyPaid
    }.with_indifferent_access.freeze

    # Must match the ENUM in MySQL for xm8_notifications
    STATES = [
      STATE_NEW = "new",
      STATE_PENDING = "pending",
      STATE_FAILED = "failed",
      STATE_SENT = "sent"
    ]

    DETAILS_NOT_REGISTERED = "recipient not registered"
    DETAILS_DM = "direct message"
    DETAILS_CUSTOM = "custom route(s)"
    DETAILS_NO_DESTINATION = "#{DETAILS_DM} disallowed, no #{DETAILS_CUSTOM}"

    class InvalidType < Exception::Error
    end

    class InvalidContent < Exception::Error
    end

    def self.from(hash)
      type = hash[:type]
      klass = TYPES[type]
      raise InvalidType, "\"#{type}\" is not a valid XM8 notification type" if klass.nil?

      hash[:content] = hash[:content].to_ostruct

      notification = klass.new(**hash.without(:type))
      notification.validate!
      notification
    end

    def self.failed_state(state_details)
      {state: Xm8Notification::STATE_FAILED, state_details:}
    end

    def self.sent_state(state_details)
      {state: Xm8Notification::STATE_SENT, state_details:}
    end

    def initialize(**opts)
      # ID is internal for tracking purposes
      opts[:id] = SecureRandom.uuid

      super

      # Notification generation data
      @context = {
        communityid: server.community.community_id,
        serverid: server.server_id,
        servername: server.server_name,
        territoryid: content.territory_id || "",
        territoryname: content.territory_name || "",
        item: content.item_name || "",
        amount: content.poptabs_received || ""
      }
    end

    def type
      @type ||= self.class.name.demodulize.underscore.dasherize
    end

    def send_to_recipients
      default_block = ->(h, k) { h[k] = [] }
      states = {
        success: Hash.new(&default_block),
        failure: Hash.new(&default_block)
      }

      user_ids = recipient_notification_mapping.keys.map(&:id)

      send_to_dm(states, user_ids)
      send_to_custom_routes(states, user_ids)

      process_undeliverable_notifications(states)
      update_notification_states(states)

      nil
    end

    def to_embed
      embed = ESM::Notification.build_random(
        community_id: server.community.id,
        type:,
        category: "xm8",
        **@context
      )

      embed.footer = "[#{server.server_id}] #{server.server_name}"
      embed
    end

    def validate!
      raise InvalidContent unless valid?
    end

    private

    def valid?
      # Most notifications are about a territory
      content.territory_id.present? && content.territory_name.present?
    end

    def send_to_dm(states, user_ids)
      preferences_by_user_id = ESM::UserNotificationPreference.where(user_id: user_ids)
        .pluck(:user_id, Arel.sql(type.underscore))
        .to_h

      # Default the preference to allow.
      # This is needed if the user hasn't ran the preference command before
      preferences_by_user_id.default = true

      recipient_notification_mapping.each do |user, uuid|
        dm_allowed = preferences_by_user_id[user.id]
        next unless dm_allowed

        message = ESM.bot.deliver(to_embed, to: user.discord_user, block: true)

        states[message ? :success : :failure][uuid] << DETAILS_DM
      end
    end

    # Custom routes are a little different.
    #   Using a mention in an embed does not cause a "notification" on discord.
    #     This does not work since these are often urgent.
    #   To get around this, routes need to be grouped by channel.
    #   From here, an initial message can be sent tagging each user with this channel (and type)
    def send_to_custom_routes(states, user_ids)
      user_lookup = recipient_notification_mapping.keys.to_h { |u| [u.id, u] }

      users_by_channel_id = ESM::UserNotificationRoute.enabled
        .accepted
        .where(notification_type: type, user_id: user_ids)
        .where("source_server_id IS NULL OR source_server_id = ?", server.id)
        .pluck(:channel_id, :user_id)
        .group_by(&:first)
        .transform_values { |g| g.map { |(_channel_id, user_id)| user_lookup[user_id] } }

      users_by_channel_id.each do |channel_id, users|
        message = ESM.bot.deliver(
          to_embed,
          to: channel_id,
          embed_message: "#{type.titleize} - #{users.map(&:mention).join(" ")}",
          block: true
        )

        notification_uuids = users.map { |u| recipient_notification_mapping[u] }
        notification_uuids.each do |uuid|
          states[message ? :success : :failure][uuid] << DETAILS_CUSTOM
        end
      end
    end

    # Handle notifications in which the recipient has blocked direct message
    # and has no custom routes for the notification to be sent to.
    def process_undeliverable_notifications(states)
      recipient_notification_mapping.values.each do |uuid|
        next if states[:success].key?(uuid) || states[:failure].key?(uuid)

        states[:failure][uuid] << DETAILS_NO_DESTINATION
      end
    end

    def update_notification_states(states)
      state_update = {}

      states[:success].each do |uuid, state|
        state_update[uuid] = self.class.sent_state(state.to_sentence)
      end

      states[:failure].each do |uuid, state|
        state_update[uuid] = self.class.failed_state(state.to_sentence)
      end

      message = ESM::Message.new
        .set_type(:query)
        .set_data(
          query_function_name: "update_xm8_notification_state",
          **state_update
        )

      server.send_message(message, block: false)
    end
  end
end
