# frozen_string_literal: true

module ESM
  module Command
    class ArgumentContainer < Array
      attr_accessor :command
      attr_reader :matches

      def parse!(event)
        @event = event

        # Reset all the values of our arguments
        self.clear!

        # Remove the prefix and command name from the message
        @message = extract_argument_string(event.message.content)

        # Loop through each match
        self.each do |argument|
          parse_and_remove!(argument)
        end
      end

      def to_s
        return "" if self.blank?

        self.format do |argument|
          output = "**`#{argument}`**\n"

          # Only add the period to optional if there is no default
          output += "Optional#{argument.default? ? "" : ". "}" if !argument.required?
          output += ", defaults to `#{argument.default}`. " if argument.default?
          output += "#{argument.description(command.prefix)}\n\n"

          output
        end
      end

      def clear!
        @matches = []
        self.each { |argument| argument.value = nil }
      end

      def community_id?
        self.any? { |argument| argument.name == :community_id }
      end

      def to_h
        hash = {}

        self.each do |argument|
          hash[argument.name] = argument.value
        end

        hash
      end

      # Pulls the values for arguments from a hash with the key being the argument name
      def from_hash(hash)
        self.each do |argument|
          argument.value = hash[argument.name.to_s]
        end
      end

      # rubocop:disable Style/MethodMissingSuper
      # Act like ostruct and return nil if the method isn't defined
      def method_missing(method_name, *arguments, &block)
        self.send(method_name, *arguments, &block) if self.class.method_defined?(method_name)
      end
      # rubocop:enable Style/MethodMissingSuper

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      private

      def parse_and_remove!(argument)
        regex = build_regex(argument)
        match = regex.match(@message)

        invalid_argument!(argument) if match.blank?

        # Store the match
        process_match(match[1], argument)

        # Now we need to return the message without our match
        @message.sub!(match[0], "")
      end

      def build_regex(argument)
        options = Regexp::IGNORECASE
        options += Regexp::MULTILINE if argument.multiline?

        # I'd rather duplicate a string than have a long concat or nasty interpolation
        regex =
          if argument.required?
            "\\s+(#{argument.regex.source})"
          else
            "\\s*(#{argument.regex.source})?"
          end

        Regexp.new(regex, options)
      end

      def invalid_argument!(argument)
        embed =
          ESM::Embed.build do |e|
            e.title = "**Missing argument `#{argument}` for `#{self.command.distinct}`**"
            e.description = "```#{self.command.distinct} #{build_error_description}```"

            e.add_field(
              name: "Arguments:",
              value: self.to_s
            )

            e.footer = "For more information, send me `#{command.prefix}help #{self.command.name}`"
          end

        raise ESM::Exception::FailedArgumentParse, embed
      end

      def process_match(match, argument)
        value =
          if match.nil?
            # Use the default value if we have one
            !argument.default.blank? ? argument.default : nil
          else
            # If we don't want to preserve the case, convert it to lowercase
            argument.preserve_case? ? match : match.downcase
          end

        # Cast the value if we need to
        value = cast_value_type(argument, value)

        # Save the value of the argument
        argument.value = value

        # Store the raw matches
        @matches << value

        # Create a getter on our container
        create_getter(argument)
      end

      def create_getter(argument)
        # Creates a method on this instance that returns the value of the argument
        self.define_singleton_method(argument.name) do
          argument.value
        end
      end

      def cast_value_type(argument, value)
        return value if argument.type == :string

        begin
          case argument.type
          when :integer
            value.to_i
          when :float
            value.to_f
          when :json
            JSON.parse(value)
          when :symbol
            value.to_sym
          else
            value
          end
        rescue StandardError
          value
        end
      end

      def build_error_description
        # This creates a usage string of the command
        # but replacing out arguments, already captured by the container, with their values
        # !test <foo> <bar>
        # !test foo <bar>
        self.format do |a|
          if a.value.nil?
            "#{a} "
          else
            "#{a.value} "
          end
        end
      end

      # Aliases may be of different lengths, this accounts for the different lengths when parsing the command string
      # For example: "!server_territories".size (default) is not the same length as "!all_territories".size (alias)
      def extract_argument_string(content)
        command_aliases = self.command.aliases + [self.command.name]

        # Determine what alias they are using.
        # I can't use `alias` as a variable, so `alias_` is how it's going to be
        command_alias =
          command_aliases.find do |alias_|
            content.match?(/^#{self.command.prefix}#{alias_}/i)
          end

        # Remove the prefix and alias.
        # Note: We're not caring about the prefix for this.
        content.sub(/#{self.command.prefix}#{command_alias}/i, "")
      end
    end
  end
end
