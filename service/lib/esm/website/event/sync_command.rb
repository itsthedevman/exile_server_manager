# frozen_string_literal: true

module ESM
  module Website
    module Event
      ##
      # Drives a command the website is waiting on and returns what it replied with. Mirrors
      # {ESM::Website::Event::AsyncCommand}, except nothing is recorded along the way: there is no
      # {ESM::ServiceCommand} row to dispatch, settle, or poll, because the request that asked for the value has not
      # been answered yet.
      #
      class SyncCommand
        delegate :user, to: :@event

        def initialize(event)
          @event = event
        end

        ##
        # Runs command_class and returns its reply payload.
        #
        def on_execution(command_class)
          origin = ESM::Website::Command::SyncOrigin.new(@event)

          @command = command_class.new(arguments: @event.arguments, origin:)
          @command.skip_action(:cooldown)

          @command.from_website!

          origin.result
        rescue => error
          on_error(error)
        end

        ##
        # The async path can record a failure on its row and return; here the caller is still holding a web request
        # open, so the error goes back to it and the RPC answers with a failure the website degrades from.
        #
        def on_error(error)
          # An application error is the command telling the player something, and it travels as-is. Anything else is a
          # bug that the async path's row would have carried into the logs, so log it before it leaves.
          raise error if error.is_a?(ESM::Exception::ApplicationError)

          ESM.discord_bot.log_error(
            user: user.attributes_for_logging,
            event: @event.arguments,
            message: error.inspect,
            backtrace: ESM.backtrace_cleaner.clean(error.backtrace)
          )

          raise error
        end
      end
    end
  end
end
