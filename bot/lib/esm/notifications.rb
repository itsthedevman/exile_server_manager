# frozen_string_literal: true

module ESM
  class Notifications
    EVENTS = %w[
      argument_parse
      websocket_server_deliver
      websocket_client_on_message
      command_from_discord
      command_from_server
      bot_deliver
      bot_resend_queue
    ].freeze

    def self.subscribe
      EVENTS.each do |event|
        ActiveSupport::Notifications.subscribe("#{event}.esm", &method(event))
      end
    end

    def self.command_from_discord(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.debug(name) do
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

      ESM.logger.debug(name) do
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
      ESM.logger.debug(name) do
        JSON.pretty_generate(payload[:request].to_h)
      end
    end

    def self.websocket_client_on_message(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        JSON.pretty_generate(JSON.parse(payload[:event].data))
      end
    end

    def self.bot_deliver(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        JSON.pretty_generate(
          channel: "#{payload[:channel].name} (#{payload[:channel].id})",
          message: payload[:message].to_s
        )
      end
    end

    def self.bot_resend_queue(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        exception = payload[:exception]

        JSON.pretty_generate(
          exception: exception.message,
          backtrace: exception.backtrace[0..2],
          message: payload[:message],
          to: payload[:to]
        )
      end
    end
  end
end
