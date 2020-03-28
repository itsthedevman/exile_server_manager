# frozen_string_literal: true

module ESM
  module Command
    class Base
      module LoggingMethods
        def log_from_discord_event
          ESM.logger.info("#{self.class}##{__method__}") do
            [
              "Author: #{current_user.distinct} (#{current_user.id})",
              "Channel: #{Discordrb::Channel::TYPE_NAMES[@event.channel.type]} (#{@event.channel.id})",
              "Command: #{@name}",
              "Arguments: #{@arguments.map(&:value)}"
            ].join("\n")
          end
        end

        def log_from_server_event
          ESM.logger.info("#{self.class}##{__method__}") do
            [
              "Author: #{current_user.distinct} (#{current_user.id})",
              "Channel: #{Discordrb::Channel::TYPE_NAMES[current_channel&.type]} (#{current_channel&.id})",
              "Command: #{@name}",
              "Arguments: #{@arguments.map(&:value)}",
              "Response: #{@response}"
            ].join("\n")
          end
        end
      end
    end
  end
end
