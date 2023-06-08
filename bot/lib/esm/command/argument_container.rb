# frozen_string_literal: true

module ESM
  module Command
    class ArgumentContainer < Array
      attr_reader :matches, :command

      def initialize(command, arguments = [])
        super(arguments.map { |name, opts| ESM::Command::Argument.new(name, opts) })

        @matches = []
        @command = command
      end

      def get(argument_name)
        find { |argument| argument.name == argument_name.to_sym }
      end

      def parse!(content)
        # Reset all the values of our arguments
        clear!

        # Remove the prefix and command name from the message
        message = extract_argument_string(content)

        # Loop through each match
        each do |argument|
          parse_and_remove!(message, argument)
        end
      end

      def validate!
        each { |argument| invalid_argument!(argument) if argument.invalid? }
      end

      def to_s
        return "" if blank?

        self.format do |argument|
          output = "**`#{argument}`**\n"

          # Only add the period to optional if there is no default
          output += "#{argument.description(command.prefix)}."
          output += "\n**Note:** This argument is optional#{argument.default? ? "" : ". "}" if !argument.required?
          output += " and it defaults to `#{argument.default}`. " if argument.default?

          output + "\n\n"
        end
      end

      def clear!
        @matches = []
        each { |argument| argument.content = nil }
      end

      def community_id?
        any? { |argument| argument.name == :community_id }
      end

      def to_h
        hash = {}

        each do |argument|
          hash[argument.name] = argument.content
        end

        hash
      end

      # Pulls the values for arguments from a hash with the key being the argument name
      def from_hash(hash)
        each do |argument|
          argument.content = hash[argument.name.to_s]
          create_getter(argument)
        end
      end

      # Act like ostruct and return nil if the method isn't defined
      def method_missing(method_name, *arguments, &block)
        send(method_name, *arguments, &block) if self.class.method_defined?(method_name)
      end
      # rubocop:enable Style/MethodMissingSuper

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      def invalid_argument!(argument)
        embed =
          ESM::Embed.build do |e|
            e.title = "**Missing argument `#{argument}` for `#{command.distinct}`**"
            e.description = "```#{command.distinct} #{build_error_description}```"

            e.add_field(
              name: "Arguments:",
              value: to_s
            )

            e.footer = "For more information, send me `#{command.prefix}help #{command.name}`"
          end

        raise ESM::Exception::FailedArgumentParse, embed
      end

      private

      def parse_and_remove!(message, argument)
        argument.parse(message, command)

        # Store the match
        @matches << argument.content

        # Create a getter on our container
        create_getter(argument)

        # Now we need to return the message without our match
        message.sub!(argument.match, "").strip! unless argument.content.nil? || argument.skip_removal?
      end

      def create_getter(argument)
        # Creates a method on this instance that returns the value of the argument
        define_singleton_method(argument.name) do
          argument.content
        end
      end

      def build_error_description
        # This creates a usage string of the command
        # but replacing out arguments, already captured by the container, with their values
        # !test <foo> <bar>
        # !test foo <bar>
        self.format { |argument| "#{argument.content || argument} " }
      end

      # Aliases may be of different lengths, this accounts for the different lengths when parsing the command string
      # For example: "!server_territories".size (default) is not the same length as "!all_territories".size (alias)
      def extract_argument_string(content)
        command_aliases = command.aliases + [command.name]

        # Determine what alias they are using.
        # I can't use `alias` as a variable, so `alias_` is how it's going to be
        command_alias =
          command_aliases.find do |alias_|
            content.match?(/^#{command.prefix}#{alias_}\b/i)
          end

        # Remove the prefix and alias.
        # Note: We're not caring about the prefix for this.
        content.sub(/#{command.prefix}#{command_alias}/i, "")
      end
    end
  end
end
