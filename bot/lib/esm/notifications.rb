# frozen_string_literal: true

module ESM
  class Notifications
    EVENTS = [
      "argument_parse.esm",
      "websocket_deliver.esm"
    ].freeze

    def self.subscribe
      EVENTS.each do |event|
        ActiveSupport::Notifications.subscribe(event, &method(event.underscore.gsub(".", "_")))
      end
    end

    def self.argument_parse_esm(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        <<~MESSAGE
          Argument: #{payload[:argument]}
          Message: "#{payload[:message]}"
          Regex: #{payload[:regex]}
          Match: #{payload[:match].inspect}
        MESSAGE
      end
    end

    def self.websocket_deliver_esm(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        payload[:request].to_s
      end
    end
  end
end
