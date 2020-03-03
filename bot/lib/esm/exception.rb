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

    # Raised if a server fails to authenticate to the Websocket server
    class FailedAuthentication < Error; end

    # Raised if the parser failed to find the argument in a message from a user
    class FailedArgumentParse < DataError; end

    # Generic exception for any checks
    class CheckFailure < DataError; end

    # exception embed for when the user tries to run a Text only command in PM
    class CommandTextOnly < DataError
      def initialize(user)
        super("")
        @data =
          ESM::Embed.build do |e|
            e.description = t("exceptions.text_only", user: user)
            e.color = :red
          end
      end
    end

    # exception embed for when the user tries to run a PM only command in Text channel
    class CommandDMOnly < DataError
      def initialize(user)
        super("")
        @data =
          ESM::Embed.build do |e|
            e.description = t("exceptions.dm_only", user: user)
            e.color = :red
          end
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
