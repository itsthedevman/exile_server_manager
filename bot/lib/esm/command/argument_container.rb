# frozen_string_literal: true

module ESM
  module Command
    class ArgumentContainer < Array
      attr_accessor :command
      attr_reader :matches

      def initialize(arguments = [])
        super(arguments.map { |name, opts| ESM::Command::Argument.new(name, self, opts) })
        @matches = []
      end

      def get(argument_name)
        find { |argument| argument.name == argument_name.to_sym }
      end

      def parse!(event)
        @event = event

        # Reset all the values of our arguments
        clear!

        # Remove the prefix and command name from the message
        @message = extract_argument_string(@event.message.content)

        # Loop through each match
        each do |argument|
          parse_and_remove!(argument)
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
        each do |argument|
          next if argument.parser.nil?

          argument.value = nil
        end
      end

      def community_id?
        any? { |argument| argument.name == :community_id }
      end

      def to_h
        hash = {}

        each do |argument|
          hash[argument.name] = argument.value
        end

        hash
      end

      # Pulls the values for arguments from a hash with the key being the argument name
      def from_hash(hash)
        each do |argument|
          argument.value = hash[argument.name.to_s]
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

      def defaults
        @defaults ||= {
          community_id: {
            regex: ESM::Regex::COMMUNITY_ID_OPTIONAL,
            description: "default_arguments.community_id",
            before_store: lambda do |parser|
              return if parser.value.present?
              return if !@event&.channel&.text?

              parser.value = current_community.community_id
            end
          },
          target: {
            regex: ESM::Regex::TARGET,
            description: "default_arguments.target"
          },
          server_id: {
            regex: ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY,
            description: "default_arguments.server_id",
            preserve: true,
            before_store: lambda do |parser|
              return if parser.value.blank?
              return if !@event&.channel&.text?

              # If we start with a community ID, just accept the match
              return if parser.value.match("^#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

              # Add the community ID to the front of the match
              parser.value = "#{current_community.community_id}_#{parser.value}"
            end
          },
          territory_id: {
            regex: ESM::Regex::TERRITORY_ID,
            description: "default_arguments.territory_id"
          }
        }
      end

      private

      def parse_and_remove!(argument)
        argument.parse(command, @message)

        # Store the match
        @matches << argument.value

        # Create a getter on our container
        create_getter(argument)

        # Now we need to return the message without our match
        @message.sub!(argument.parser.original, "").strip! unless argument.value.nil? || argument.skip_removal?
      end

      def create_getter(argument)
        # Creates a method on this instance that returns the value of the argument
        define_singleton_method(argument.name) do
          argument.value
        end
      end

      def build_error_description
        # This creates a usage string of the command
        # but replacing out arguments, already captured by the container, with their values
        # !test <foo> <bar>
        # !test foo <bar>
        self.format do |argument|
          if argument.parser.nil? || argument.value.nil?
            "#{argument} "
          else
            "#{argument.value} "
          end
        end
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
