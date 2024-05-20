# frozen_string_literal: true

module ESM
  module Event
    #
    # Delegator over Discordrb::Events::ApplicationCommandEvent
    #
    class ApplicationCommand
      delegate :user, :channel, :options, :respond, :edit_response, :delete_response, to: :@event

      def initialize(event)
        @event = event

        @tip_key = "tip_counter"
        @tip = ESM.config.tips.sample

        @embed_template =
          ESM::Embed.build do |e|
            e.color = Color::BLUE
          end

        @backtrace_cleaner = ActiveSupport::BacktraceCleaner.new
        @backtrace_cleaner.add_filter { |line| line.gsub(ESM.root.to_s, "") }
        @backtrace_cleaner.add_silencer { |line| /gems/.match?(line) }
      end

      #
      # Discordrb's ApplicationCommandEvent code does not appear to handle if there is no server_id and crashes
      #
      def server
        return if @event.server_id.nil?

        @event.server
      end

      def on_execution(command_class)
        respond(content: "Processing your request...")

        @command = command_class.new(user:, server:, channel:, arguments: options)

        ESM::ApplicationRecord.connection_pool.with_connection do
          @command.from_discord!
          on_completion
        rescue => error
          on_error(error)
        end
      end

      def on_completion
        content = ":stopwatch: Completed in #{@command.timers.humanized_total}"
        content = add_tip(content)

        edit_response(content: content)

        @command
      end

      def on_error(error)
        return delete_response if error.is_a?(Exception::CheckFailureNoMessage)

        content =
          if error.is_a?(Exception::CheckFailure)
            ":warning: I was unable to complete your request :warning:\n"
          else
            ":grimacing: Well, this is awkward... :grimacing:\n"
          end

        edit_response(content: content)

        message =
          case error
          when ESM::Exception::DataError
            error.data
          when StandardError
            uuid = SecureRandom.uuid.split("-")[0..1].join("")

            ESM.bot.log_error(
              uuid: uuid,
              user: @command&.current_user&.attributes_for_logging,
              message: error.message,
              backtrace: @backtrace_cleaner.clean(error.backtrace)
            )

            ESM::Embed.build(:error, description: I18n.t("exceptions.system", error_code: uuid))
          end

        ESM.bot.deliver(message, to: channel)

        @command
      end

      def send_tip?
        @send_tip ||= lambda do
          counter = ESM.cache.increment(@tip_key)
          send_tip = counter > (1 + (1 + rand + rand).round)

          ESM.cache.delete(@tip_key) if send_tip # Reset the counter

          send_tip
        end.call
      end

      def add_tip(content)
        return content unless send_tip?

        content + "\n:information_source: **Did you know?** *#{@tip}*"
      end
    end
  end
end
