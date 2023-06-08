# frozen_string_literal: true

# 2022-04-02 This should be phased out and just use other logic to perform these tasks

module ESM
  class Notifications
    EVENTS = %w[
      ready
      server_on_connect
      websocket_server_on_close
      websocket_server_deliver
      command_from_discord
      command_from_server
      command_check_failed
      bot_deliver
      websocket_client_on_message
      xm8_notification_invalid_type
      xm8_notification_invalid_attributes
      xm8_notification_on_send
    ].freeze

    def self.trigger(name, **args)
      raise ESM::Exception::Error, "#{name} is not a whitelisted notification event" if !EVENTS.include?(name)

      ActiveSupport::Notifications.instrument("#{name}.esm", args)
    rescue => e
      ESM.logger.error("#{self.class}##{__method__}") { ESM::JSON.pretty_generate(uuid: SecureRandom.uuid, message: e.message, backtrace: e.backtrace) }
    end

    def self.subscribe
      EVENTS.each do |event|
        ActiveSupport::Notifications.subscribe("#{event}.esm", &method(event))
      end
    end

    def self.ready(name, _start, _finish, _id, _payload)
      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          invite_url: ESM.bot.invite_url(permission_bits: ESM::Bot::PERMISSION_BITS)
        )
      end
    end

    def self.command_from_discord(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          command: command.to_h
        )
      end
    end

    def self.command_check_failed(name, _start, _finish, _id, payload)
      command = payload[:command]
      reason = payload[:reason]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          reason: reason.is_a?(Embed) ? reason.description : reason,
          command: command.to_h
        )
      end
    end

    def self.command_from_server(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.nil?
      return if command.event.nil?

      ESM.logger.info(name) do
        JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          response: payload[:response],
          command: command.to_h
        )
      end
    end

    def self.websocket_server_deliver(name, _start, _finish, _id, payload)
      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(payload[:request].to_h)
      end
    end

    def self.websocket_client_on_message(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        ESM::JSON.pretty_generate(payload[:event].data)
      end
    end

    def self.bot_deliver(name, _start, _finish, _id, payload)
      message = payload[:message]

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          channel: "#{payload[:channel].name} (#{payload[:channel].id})",
          message: message.is_a?(ESM::Embed) ? message.to_h : message
        )
      end
    end

    def self.xm8_notification_invalid_type(_name, _start, _finish, _id, payload)
      server = payload[:server]
      recipients = payload[:recipients].join("\n")

      embed =
        ESM::Embed.build do |e|
          e.title = I18n.t("xm8_notifications.invalid_type.title", server: server.server_id)
          e.description = I18n.t("xm8_notifications.invalid_type.description", type: payload[:type])

          e.add_field(name: I18n.t(:message), value: "```#{payload[:message]}```")
          e.add_field(name: I18n.t("xm8_notifications.recipient_steam_uids"), value: "```#{recipients}```")

          e.color = :red
          e.footer = I18n.t("xm8_notifications.footer")
        end

      server.community.log_event(:xm8, embed)
    end

    def self.xm8_notification_invalid_attributes(_name, _start, _finish, _id, payload)
      server = payload[:server]
      recipients = payload[:recipients].join("\n")
      type = payload[:type]
      message = payload[:message]
      error, remedy = ""

      case type
      when "custom"
        error = I18n.t("xm8_notifications.invalid_attributes.custom.error")
        remedy = I18n.t("xm8_notifications.invalid_attributes.custom.remedy")
      when "marxet-item-sold"
        error = I18n.t("xm8_notifications.invalid_attributes.marxet_item_sold.error")
        remedy = I18n.t("xm8_notifications.invalid_attributes.marxet_item_sold.remedy")
      end

      embed =
        ESM::Embed.build do |e|
          e.title = I18n.t("xm8_notifications.invalid_attributes.title", server: server.server_id)
          e.description = I18n.t("xm8_notifications.invalid_attributes.description", error: error, remedy: remedy)

          log_message = I18n.t("xm8_notifications.invalid_attributes.log_message.base")
          log_message += I18n.t("xm8_notifications.invalid_attributes.log_message.title", title: message.title) if message.title.present?
          log_message += I18n.t("xm8_notifications.invalid_attributes.log_message.title", message: message.description) if message.description.present?

          e.add_field(name: I18n.t(:message), value: log_message)
          e.add_field(name: I18n.t("xm8_notifications.recipient_steam_uids"), value: "```#{recipients}```")

          e.color = :red
          e.footer = I18n.t("xm8_notifications.footer")
        end

      server.community.log_event(:xm8, embed)
    end

    def self.xm8_notification_on_send(name, _start, _finish, _id, payload)
      server = payload[:server]
      notification = payload[:embed]
      type = payload[:type]
      unregistered_steam_uids = payload[:unregistered_steam_uids]

      message_statuses = payload[:statuses].map do |user, hash|
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
          "xm8_notifications.log.message_statuses.values.direct_message.#{direct_message}",
          user: "#{user.discord_username}##{user.discord_discriminator}",
          steam_uid: user.steam_uid
        )

        custom_route_status = I18n.t(
          "xm8_notifications.log.message_statuses.values.custom_routes.#{custom_routes}",
          number_sent: hash[:custom_routes][:sent],
          number_expected: hash[:custom_routes][:expected]
        )

        status = "**#{user.distinct}** (`#{user.steam_uid}`)\n **-** #{direct_message_status}"
        status += "\n **-** #{custom_route_status}" if custom_route_status.present?
        status
      end

      # For debugging
      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          type: type,
          server: server.server_id,
          embed: notification.to_h,
          message_statuses: message_statuses,
          unregistered_steam_uids: unregistered_steam_uids,
          log: server.community.log_xm8_event?
        )
      end

      # Notify the community if they subscribe to this notification
      embed =
        ESM::Embed.build do |e|
          e.title = I18n.t("xm8_notifications.log.title", type: type, server: server.server_id)
          e.description = I18n.t("xm8_notifications.log.description", title: notification.title, description: notification.description)

          if message_statuses.present?
            e.add_field(
              name: I18n.t("xm8_notifications.log.message_statuses.name"),
              value: message_statuses.join("\n\n")
            )
          end

          if unregistered_steam_uids.present?
            e.add_field(
              name: I18n.t("xm8_notifications.log.unregistered_steam_uids"),
              value: unregistered_steam_uids
            )
          end

          e.color = ESM::Color.random
          e.footer = I18n.t("xm8_notifications.footer")
        end

      server.community&.log_event(:xm8, embed)
    end

    def self.server_on_connect(name, _start, _finish, _id, payload)
      server = payload[:server]

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(server_id: server.server_id, uptime: server.uptime)
      end

      server.community&.log_event(:reconnect, I18n.t("server_connected", server: server.server_id, uptime: server.uptime))
    end

    def self.websocket_server_on_close(name, _start, _finish, _id, payload)
      server = payload[:server]

      ESM.logger.debug(name) do
        ESM::JSON.pretty_generate(bot_stopping: ESM.bot.stopping?, server_id: server.server_id, uptime: server.uptime)
      end

      message =
        if ESM.bot.stopping?
          I18n.t("server_disconnected_esm_stopping", server: server.server_id, uptime: server.uptime)
        else
          I18n.t("server_disconnected", server: server.server_id, uptime: server.uptime)
        end

      server.community&.log_event(:reconnect, message)
    end
  end
end
