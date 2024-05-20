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

    # When the bot does not have access to send a message to a particular channel
    class ChannelAccessDenied < Error; end

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

    ###########################################################
    # Connection and extension related errors
    #

    # Base type that causes a connection close
    class ClosableError < Error
    end

    #
    # Base type that will send the error back to the client
    #
    class SendableError < DataError
    end

    class ExtensionError < DataError
    end

    class DecryptionError < ClosableError
    end

    class InvalidRequest < SendableError
    end

    class RequestTimeout < DataError
      def initialize = super("Request timed out")
    end

    class ExistingConnection < ClosableError
      def initialize = super("Client already connected")
    end

    class InvalidAccessKey < ClosableError
      def initialize = super("Access denied")
    end

    class RejectedPromise < ClosableError
      def initialize(reason = "") = super(reason)
    end
  end
end
