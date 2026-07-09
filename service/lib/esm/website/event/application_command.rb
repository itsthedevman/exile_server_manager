# frozen_string_literal: true

module ESM
  module Website
    module Event
      class ApplicationCommand
        delegate :user, to: :@event

        def initialize(event)
          @event = event
        end

        def on_execution(command_class)
          @event.update!(status: :dispatched)

          @command = command_class.new(
            arguments: @event.arguments,
            origin: ESM::Website::Command::Origin.new(@event)
          )

          @command.from_website!
          @command
        rescue => error
          on_error(error)
        end

        def on_error(error)
          case error
          when Exception::CheckFailureNoMessage
            @event.update!(status: :failed)
          when ESM::Exception::RequestTimeout
            @event.update!(status: :timed_out)
          when ESM::Exception::ApplicationError
            @event.update!(status: :failed, error_message: error.data.join("\n"))
          when StandardError
            ESM.discord_bot.log_error(
              user: user.attributes_for_logging,
              event: @event.attributes,
              message: error.inspect,
              backtrace: ESM.backtrace_cleaner.clean(error.backtrace)
            )

            @event.update!(status: :failed)
          end

          @command
        end
      end
    end
  end
end
