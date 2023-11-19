# frozen_string_literal: true

module ESM
  module Exception
    # Base exception
    class Error < StandardError; end

    # This exception allows attaching extra data to the exception
    # This is mainly used for exception embeds
    class DataError < Error
      attr_reader :data

      def initialize(data)
        # So if #message is called, it will return that.
        super(data.to_s)

        # Store the embed in the message
        # I had to do it this way because StandardError converts the message to a string
        @data = data
      end
    end

    # Internally used exception.
    # Raised if I pull a stupid and define a command twice
    class DuplicateCommand < Error; end

    # Internally used exception.
    # Raised to keep me in my place and ensure I define arguments correctly
    class InvalidCommandArgument < Error; end

    # Raised when a command attempts to set its namespace with more than one subgroups
    class InvalidCommandNamespace < Error; end

    # Raised if a server fails to authenticate to the Websocket server
    class FailedAuthentication < Error; end

    # Raised when a message fails validation or fails to create
    class InvalidMessage < Error; end

    # Raised if the provided argument value from the user is invalid
    class InvalidArgument < DataError; end

    # Generic exception for any checks
    class CheckFailure < DataError; end

    # Raised when attempting to send a message the tcp_server when it's not online
    class ServerNotConnected < Error; end

    # Raised when a message times out during a sync operation. This should rarely be raised
    class MessageSyncTimeout < Error; end

    # When the bot does not have access to send a message to a particular channel
    class ChannelAccessDenied < Error; end

    # Handles an error code response from the extension
    class ExtensionError < Error
      def initialize(error_code)
        @error_code = error_code

        super("")
      end

      # Translates the underlying error code.
      # In normal workflow, this method will be passed the following arguments:
      # @option [String] :user The mention for the user that ran the command
      # @option [String] :server_id The ID of the server the command was ran on
      def translate(**)
        I18n.t(
          "exceptions.extension.#{@error_code}",
          default: I18n.t("exceptions.extension.default", error_code: @error_code),
          **
        )
      end
    end

    # Check failure, but no message is sent
    class CheckFailureNoMessage < Error
      def initialize(_message)
        super("")
      end
    end

    # Raised when ESM can't find a channel passed into it's deliver method.
    class ChannelNotFound < Error
      def initialize(message, channel)
        error_message = "Failed to send message!\nMessage: #{message}\nAttempted to send to channel: "
        error_message += channel.to_s if channel.present?

        super(error_message)
      end
    end
  end
end
