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
        @message = event.message.content[@command.offset..-1]

        # Loop through each match
        self.each do |argument|
          parse_and_remove!(argument)
        end
      end

      def to_s
        return "" if self.blank?

        self.format do |argument|
          output = "**`#{argument}`:**"

          # Only add the period to optional if there is no default
          output += " Optional#{argument.default? ? "" : "."}" if !argument.required?
          output += ", defaults to `#{argument.default}`." if argument.default?
          output += " #{argument.description}\n"

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
              value: self.command.arguments.to_s
            )

            e.footer = "For more information, send me `#{ESM.config.prefix}help #{self.command.name}`"
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
    end
  end
end
