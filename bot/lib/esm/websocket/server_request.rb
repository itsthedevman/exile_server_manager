# frozen_string_literal: true

module ESM
  class Websocket
    class ServerRequest
      WHITELISTED_SERVER_COMMANDS = %w[
        server_initialization
        xm8_notification
        discord_log
        discord_message_channel
      ].freeze

      def initialize(connection:, message:)
        @connection = connection
        @message = message
        @request = @connection.requests[message.commandID]
        @request.on_reply(connection) if @request.present?
      end

      # These are normally empty responses
      # message.returned is legacy
      def invalid?
        @message.ignore || @message.returned
      end

      # Checks if the request should be removed on the first ignore
      def remove_on_ignore?
        @request ? @request.remove_on_ignore : false
      end

      def process
        if @request.present?
          process_command_response
        else
          process_server_command
        end
      end

      # Removes the request from the queue if present
      def remove_request
        @connection.remove_request(@message.commandID) if @request
      end

      private

      # @private
      # Processes a command response from the A3 server.
      def process_command_response
        # Save this response on the request
        @request.response = @message.parameters

        # Logging
        ESM::Notifications.trigger("command_from_server", command: @request.command, response: @message)

        # We have an error from the DLL
        check_for_command_error!

        # Execute the command
        begin
          @request.command.execute(@message.parameters)
        rescue ESM::Exception::CheckFailure => e
          # This catches any errors from the command.
          @request.command.reply(e.data)
        end

      # This catches the check_for_command_error
      rescue ESM::Exception::CheckFailure => e
        on_command_error(e.data)
      ensure
        # Make sure to remove the request no matter what
        remove_request
      end

      # @private
      # Processes server command that doesn't come from a request.
      def process_server_command
        return if !WHITELISTED_SERVER_COMMANDS.include?(@message.command)

        # Build the class and call it
        "ESM::Event::#{@message.command.classify}".constantize.new(
          connection: @connection,
          server: @connection.server,
          parameters: @message.parameters.first
        ).run!
      end

      # @private
      # Reports the error back to the user so they know the command failed
      def on_command_error(error)
        return if @request.user.nil?

        # Reset the current cooldown
        @request.command.current_cooldown.reset!

        # Some errors from the dll already have a mention in them...
        error = "#{@request.user.mention}, #{error}" if !error.start_with?("<")

        # Send the error message
        embed = ESM::Embed.build(:error, description: error)
        @request.command.reply(embed)
      end

      # Error responses from a command
      #
      # @private
      def check_for_command_error!
        raise ESM::Exception::CheckFailure, @message.error if @message.error.present?
        raise ESM::Exception::CheckFailure, @message.parameters.first.error if @message.parameters&.first&.error&.present?
      end
    end
  end
end
