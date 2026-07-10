# frozen_string_literal: true

module ESM
  module Exception
    # Base exception
    class Error < StandardError; end

    # This exception allows attaching extra data to the exception
    # This is mainly used for exception embeds
    class ApplicationError < Error
      attr_reader :data

      def initialize(data)
        # So if #message is called, it will return that.
        super(data.to_s)

        @data = data
      end

      ##
      # The player-facing text for this error, medium-agnostic. Arrays (multi-line extension errors) join
      # with newlines; a structured hash yields its description line. Presentation lives in #to_embed.
      #
      def to_content
        case @data
        when Array
          @data.join("\n")
        when Hash
          @data.symbolize_keys[:description].to_s
        else
          @data.to_s
        end
      end

      def to_embed
        return @data if @data.blank?

        case @data
        # Lenient #from_hash (not the strict #from_hash!) - the hash is our own #to_h, which carries
        # keys the strict validator rejects.
        when Hash
          ESM::Embed.from_hash(@data)
        else
          ESM::Embed.build(:error, description: to_content)
        end
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
    class InvalidArgument < ApplicationError; end

    # Generic exception for any checks
    class CheckFailure < ApplicationError; end

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
    class SendableError < ApplicationError
    end

    # Raised when the Arma extension rejects a request. #data holds the player-facing error
    # strings from the response; each surface renders them itself (Discord builds an error embed
    # via the base #to_embed, the website records #to_content on the command row).
    class ExtensionError < ApplicationError
    end

    # Raised when a query or call targets a server that has no live connection,
    # so the request can fail with a clear reason instead of a NoMethodError on a
    # nil response.
    class ServerNotConnected < Error
      def initialize(server_id) = super("Server `#{server_id}` is not connected")
    end

    # Raised when inbound client data fails to decrypt or fails its key/IV/authenticity checks.
    # Closes the connection.
    class DecryptionError < ClosableError
    end

    # Raised when a client sends a request ESM can't route. The reason is sent back to the client.
    class InvalidRequest < SendableError
    end

    # Raised when a request to the client goes unanswered within the response timeout.
    class RequestTimeout < ApplicationError
      def initialize = super("Request timed out")
    end

    # Raised during identification when a client claims a public id that already has a live
    # connection. Closes the duplicate.
    class ExistingConnection < ClosableError
      def initialize = super("Client already connected")
    end

    # Raised during identification when no registered server matches the client's public id.
    # Closes the connection without telling the client why.
    class InvalidAccessKey < ClosableError
      def initialize = super("Access denied")
    end

    # Raised when a pending request promise is rejected (e.g. a handshake response that never
    # validates). Closes the connection.
    class RejectedPromise < ClosableError
      def initialize(reason = "") = super
    end

    # Raised when an inbound frame declares a length at or beyond the socket read ceiling.
    class MessageTooLarge < ApplicationError
      def initialize(size)
        super("Attempted to read #{size} bytes")
      end
    end
  end
end
