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

    # Raised by Arguments#validate! when one or more arguments fail their checks. Carries the whole invalid set at
    # once - `data` is an array of `{argument:, value:}` (the failing Argument plus what the user actually sent) -
    # so a single error can list every problem. Each surface renders it its own way: Discord builds the rich embed
    # via #to_embed, the website records the plain #to_content on the command row.
    class InvalidArguments < ApplicationError
      def initialize(data, command_instance)
        @command_instance = command_instance

        super(data)
      end

      # The surface-neutral counterpart to #to_embed: which arguments need fixing and what each one expects, as
      # plain text a website alert can show verbatim. It leans on the "_web" argument copy so nothing here carries
      # Discord chrome (mentions, slash usage, `/help`), and leads each line with the value the user actually sent.
      def to_content
        argument_word = "argument".pluralize(@data.size)

        documentation =
          @data.join_map("\n\n") do |invalid|
            argument = invalid[:argument]
            value = invalid[:value]

            # Prefer the actionable "here's what to provide" copy; fall back to the plain description when an
            # argument has no extra guidance. One guidance line only - no need to also restate what the arg is.
            hint = argument.description_extra_web.presence || argument.description_web

            copy = [
              ("#{value.inspect} isn't valid." if value.present?),
              hint
            ]

            "#{argument}: #{copy.compact_blank.join(" ")}"
          end

        "Please correct the following #{argument_word} and try again:\n\n#{documentation}"
      end

      def to_embed
        ESM::Embed.build do |e|
          help_documentation = @data.join_map("\n\n") { |invalid| invalid[:argument].help_documentation }

          help_usage = ESM::Command.get(:help).usage(
            with_args: true,
            arguments: {with: @command_instance.usage(with_slash: false, with_args: false)}
          )

          argument_word = "argument".pluralize(@data.size)

          # Echo each invalid value back in the usage line so the example shows what they sent, not a placeholder.
          invalid_values = @data.to_h { |invalid| [invalid[:argument].name, invalid[:value]] }

          e.title = "**Invalid #{argument_word}**"
          e.description = <<~STRING
            ```#{@command_instance.usage(with_args: true, use_placeholders: true, arguments: invalid_values)}```
            **Please read the following and correct any errors before trying again.**

            **Invalid #{argument_word}**
            #{help_documentation}

            For more information, use the following command:
            ```#{help_usage}```
          STRING

          e.add_field(
            name: I18n.t("commands.help.command.examples"),
            value: @command_instance.examples
          )
        end
      end
    end

    # Generic exception for any checks. Carries either a locale `key` plus interpolation `details` - rendered
    # per surface at delivery time so each medium names the user and formats the copy its own way - or a legacy
    # positional `data` (a literal string, or the embed hash from argument validation) that the base
    # ApplicationError rendering handles unchanged.
    class CheckFailure < ApplicationError
      attr_reader :key, :details

      def initialize(data = nil, key: nil, **details)
        @key = key
        @details = details
        super(data)
      end

      ##
      # Renders this failure's copy from its locale key. Any ESM::User in the details is projected through
      # `projector`, so each surface names the user its own way (mention on Discord, username on the website).
      # `suffix` lets a surface prefer a variant key (e.g. "_web") and fall back to the base key when absent.
      #
      # @param suffix [String, nil] an optional key suffix to prefer when a surface-specific variant exists
      # @param projector [Proc] projects an ESM::User into the surface's representation
      #
      # @return [String] the interpolated, surface-projected copy
      #
      def render(suffix: nil, &projector)
        lookup = (suffix && I18n.exists?("#{key}#{suffix}")) ? "#{key}#{suffix}" : key
        I18n.t(lookup, **details.transform_values { |value| user_like?(value) ? projector.call(value) : value })
      end

      # A bare #message (logs, `raise_error` matchers, backtraces) has no surface, so render the Discord copy -
      # the default medium. Literal failures fall back to StandardError's stored message.
      def message
        return super if key.nil?

        render(&:mention)
      end

      def to_embed
        return super if key.nil?

        ESM::Embed.build(:error, description: render(&:mention))
      end

      private

      # Both a registered ESM::User and the User::Ephemeral stand-in for an unregistered target answer the
      # projection methods (#mention, #username), so either should be projected rather than interpolated raw.
      def user_like?(value)
        value.is_a?(ESM::User) || value.is_a?(ESM::User::Ephemeral)
      end
    end

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
