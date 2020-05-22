# frozen_string_literal: true

module ESM
  class Notifications
    EVENTS = %w[
      argument_parse
      websocket_server_deliver
      command_from_discord
      command_from_server
      bot_deliver
      bot_resend_queue
      websocket_client_on_message
      xm8_notification_invalid_type
      xm8_notification_invalid_attributes
      xm8_notification_on_send
    ].freeze

    def self.trigger(name, **args)
      raise ESM::Exception::Error, "#{name} is not a whitelisted notification event" if !EVENTS.include?(name)

      ActiveSupport::Notifications.instrument("#{name}.esm", args)
    end

    def self.subscribe
      EVENTS.each do |event|
        ActiveSupport::Notifications.subscribe("#{event}.esm", &method(event))
      end
    end

    def self.command_from_discord(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.info(name) do
        JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          command: command.name,
          message: command.event.message.content,
          arguments: command.arguments.to_h
        )
      end
    end

    def self.command_from_server(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.info(name) do
        JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          command: command.name,
          message: command.event.message.content,
          arguments: command.arguments.to_h,
          response: payload[:response]
        )
      end
    end

    def self.argument_parse(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        JSON.pretty_generate(
          argument: payload[:argument],
          message: payload[:message],
          regex: payload[:regex],
          match: payload[:parser].value
        )
      end
    end

    def self.websocket_server_deliver(name, _start, _finish, _id, payload)
      ESM.logger.info(name) do
        JSON.pretty_generate(payload[:request].to_h)
      end
    end

    def self.websocket_client_on_message(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        JSON.pretty_generate(JSON.parse(payload[:event].data))
      end
    end

    def self.bot_deliver(name, _start, _finish, _id, payload)
      message = payload[:message]

      ESM.logger.info(name) do
        JSON.pretty_generate(
          channel: "#{payload[:channel].name} (#{payload[:channel].id})",
          message: message.is_a?(ESM::Embed) ? message.to_h : message
        )
      end
    end

    def self.bot_resend_queue(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        exception = payload[:exception]

        JSON.pretty_generate(
          message: payload[:message],
          to: payload[:to].respond_to?(:id) ? payload[:to].id : payload[:to],
          exception: exception.message,
          backtrace: exception.backtrace[0..2]
        )
      end
    end

    # server, recipients, message, type
    def self.xm8_notification_invalid_type(_name, _start, _finish, _id, payload)
      server = payload[:server]
      recipients = payload[:recipients].join("\n")

      embed =
        ESM::Embed.build do |e|
          e.title = "(Undeliverable) XM8 Notification for `#{server.server_id}`"
          e.description = <<~MESSAGE
            **Error:**
            The provided notification type of `#{payload[:type]}` is not valid.

            **Remedy:**
            Please provide a valid type in your XM8 notification request.
            You may find the valid XM8 notification types on my [wiki](https://www.esmbot.com/wiki)
          MESSAGE

          e.add_field(name: "Message", value: "```#{payload[:message]}```")
          e.add_field(name: "Recipient Steam UIDs", value: "```#{recipients}```")

          e.color = :red
          e.footer = "These notifications can be configured via the Admin Dashboard"
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
        error = "Missing `title` and/or `body` attributes in message field"
        remedy = "Please provide a valid string for `title` and/or `body`. This string cannot be empty or whitespace."
      when "marxet-item-sold"
        error = "Missing `item` and `amount` attributes in message field"
        remedy = "Please provide a valid string for `item` and `amount`. This string cannot be empty or whitespace."
      end

      embed =
        ESM::Embed.build do |e|
          e.title = "(Undeliverable) XM8 Notification for `#{server.server_id}`"
          e.description = <<~MESSAGE
            **Error:**
            #{error}

            **Remedy:**
            #{remedy}
          MESSAGE

          log_message = "The following message has been sent:\n"
          log_message += "**Title:**\n#{message.title}" if message.title.present?
          log_message += "**Message:**\n#{message.description}" if message.title.present?

          e.add_field(name: "Message", value: log_message)
          e.add_field(name: "Recipient Steam UIDs", value: "```#{recipients}```")

          e.color = :red
          e.footer = "This notification can be disabled via the Admin Dashboard"
        end

      server.community.log_event(:xm8, embed)
    end

    def self.xm8_notification_on_send(name, _start, _finish, _id, payload)
      server = payload[:server]
      notification = payload[:embed]
      type = payload[:type]
      sent_to_users = payload[:sent_to_users].map { |user| "#{user.discord_username}##{user.discord_discriminator} (`#{user.steam_uid}`)" }
      unregistered_steam_uids = payload[:unregistered_steam_uids]

      # For debugging
      ESM.logger.info(name) do
        JSON.pretty_generate(
          type: type,
          server: server.server_id,
          embed: notification.to_h,
          sent_to_users: sent_to_users,
          unregistered_steam_uids: unregistered_steam_uids,
          log: server.community.log_xm8_event?
        )
      end

      # Notify the community if they subscribe to this notification
      embed =
        ESM::Embed.build do |e|
          e.title = "(Delivered) `#{type}` XM8 Notification for `#{server.server_id}`"
          e.description = <<~MESSAGE
            **Title:**
            #{notification.title}

            **Description:**
            #{notification.description}
          MESSAGE

          e.add_field(
            name: "**Delivered To**",
            value: sent_to_users
          )

          e.add_field(
            name: "**Unregistered Steam UIDs**",
            value: unregistered_steam_uids
          )

          e.color = ESM::Color.random
          e.footer = "This notification can be configured via the Admin Dashboard"
        end

      server.community.log_event(:xm8, embed)
    end
  end
end
