# frozen_string_literal: true

module ESM
  class Websocket
    class ServerRequest
      def initialize(connection:, message:)
        @connection = connection
        @message = message
        @request = @connection.requests[message.commandID]
      end

      def process
        if @request.present?
          process_command_response
        else
          process_server_command
        end
      end

      private

      # @private
      # Processes a command response from the A3 server.
      def process_command_response
        # Save this response on the request
        @request.response = @message.parameters

        # We have an error from the DLL
        check_for_command_error!

        # Execute the command
        begin
          @request.command.execute(@message.parameters)
        rescue ESM::Exception::CheckFailure => e
          embed =
            ESM::Embed.build do |em|
              em.description = e.message
              em.color = :red
            end

          @request.command.reply(embed)
        end

        # Remove the request now that we've processed it
        @connection.remove_request(@message.commandID)
      end

      # @private
      # Processes server command that doesn't come from a request.
      def process_server_command
        case @message.command
        when "server_initialization"
          ESM::Event::ServerInitialization.new(@connection.server.server_id, @message.parameters.first).run!
        when "xm8_notification"
          ESM::Event::Xm8Notification.new(@connection.server, @message.parameters.first).run!
        end
      end

      # @private
      # Reports the error back to the user so they know the command failed
      def on_command_error(error)
        # Reset the current cooldown
        @request.command.current_cooldown.reset!

        # Some errors from the dll already have a mention in them...
        error = "#{@request.user.mention}, #{error}" if !error.start_with?("<")

        # Send the error message
        embed = ESM::Embed.build(:error, description: error)
        @request.command.reply(embed)

        # Remove the request now that we've processed it
        @connection.remove_request(@message.commandID)
      end

      # Error responses from a command
      #
      # @private
      def check_for_command_error!
        raise ESM::Exception::CheckFailure, on_command_error(@message.error) if @message.error.present?
        raise ESM::Exception::CheckFailure, on_command_error(@message.parameters.first.error) if @message.parameters&.first&.error&.present?
      end
    end
  end
end
