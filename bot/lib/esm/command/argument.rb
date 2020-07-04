# frozen_string_literal: true

module ESM
  module Command
    class Argument
      # argument :name, regex: /xxx/, preserve: true, type: :integer, display_as: "", multiline: true, default: nil
      attr_reader :name, :parser
      attr_accessor :value

      def initialize(name, opts = {})
        @valid = false
        @name = name
        @opts = load_options(opts)

        # Run some checks on the argument
        check_for_regex!
        check_for_description!
      end

      def regex
        @regex ||= lambda do
          options = Regexp::IGNORECASE
          options += Regexp::MULTILINE if self.multiline?

          regex = "(#{@opts[:regex].source})"
          regex += "?" if !self.required?

          Regexp.new(regex, options)
        end.call
      end

      def preserve_case?
        @opts[:preserve] ||= false
      end

      def required?
        !@opts.key?(:default)
      end

      def type
        @opts[:type] ||= :string
      end

      def display_as
        @opts[:display_as] ||= @name.to_s
      end

      def multiline?
        @opts[:multiline] ||= false
      end

      def default=(value)
        @opts[:default] = value
      end

      def default
        @opts[:default]
      end

      def default?
        !default.blank?
      end

      # Only valid if argument has a value and no default.
      # Allows value to be nil if not required
      def invalid?
        self.required? && self.value.nil?
      end

      def description(prefix = ESM.config.prefix || "!")
        return "" if @opts[:description].blank?

        # Call I18n with the name of the translation and pass the prefix into the translation by default
        I18n.send(:t, @opts[:description], prefix: prefix, default: "")
      end

      def to_s
        string = "<"
        string += "?" if !required?

        string +=
          if display_as.present?
            display_as.to_s
          else
            name.to_s
          end

        string + ">"
      end

      def parse(command, message)
        @parser = ESM::Command::Argument::Parser.new(self, message)

        # Allows modification of the match before storing it
        before_store(command) if before_store?

        # Logging
        ESM::Notifications.trigger("argument_parse", argument: self, regex: regex, parser: @parser, message: message)

        # Save the value of the argument
        @value = @parser.value
      end

      private

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

      def check_for_regex!
        raise ESM::Exception::InvalidCommandArgument, "Missing regex for argument :#{@name}" if @opts[:regex].nil?
      end

      def check_for_description!
        raise ESM::Exception::InvalidCommandArgument, "Missing description for argument :#{@name}" if @opts[:description].nil?
      end

      def load_options(opts)
        if default_argument?(opts[:template] || @name)
          default_from_name(opts[:template] || @name).merge(opts)
        else
          opts
        end
      end

      def default_argument?(name)
        defaults.key?(name)
      end

      def default_from_name(name)
        defaults[name]
      end

      def before_store?
        @opts.key?(:before_store) && @opts[:before_store].respond_to?(:call)
      end

      def before_store(command)
        command.instance_exec(@parser, &@opts[:before_store])
      end
    end
  end
end
