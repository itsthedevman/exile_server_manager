# frozen_string_literal: true

module ESM
  module Command
    class Argument
      # argument :name, regex: /xxx/, preserve: true, type: :integer, display_as: "", multiline: true, default: nil
      attr_reader :name, :parser
      attr_accessor :value

      def initialize(name, container, opts = {})
        @valid = false
        @name = name.clone
        @container = container
        @opts = load_options(opts.clone)

        # Run some checks on the argument
        check_for_regex!
        check_for_description!
      end

      def regex
        options = Regexp::IGNORECASE
        options += Regexp::MULTILINE if self.multiline?

        regex = "(#{@opts[:regex].source})"
        regex += "?" if !self.required?

        Regexp.new(regex, options)
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

      # Setting this to true will allow the ArgumentContainer to skip removing the matched contents of the message
      # so they can be matched by the next argument.
      def skip_removal=(value)
        @opts[:skip_removal] = value
      end

      def skip_removal?
        @opts[:skip_removal] ||= false
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
        name =
          if self.display_as.present?
            self.display_as.to_s
          else
            self.name.to_s
          end

        "<#{"?" if !required?}#{name}>"
      end

      def parse(command, message)
        @parser = ESM::Command::Argument::Parser.new(self, message)

        # Allows modifications of the argument before parsing
        before_parse(command) if before_parse?

        # Parse the value from the message
        @parser.parse!

        # Allows modification of the match before storing it
        before_store(command) if before_store?

        # Store the value parsed
        @value = @parser.value

        # Logging
        ESM::Notifications.trigger("argument_parse", argument: self, regex: regex, parser: @parser, message: message)
      end

      private

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
        @container.defaults.key?(name)
      end

      def default_from_name(name)
        @container.defaults[name]
      end

      def before_store?
        @opts.key?(:before_store) && @opts[:before_store].respond_to?(:call)
      end

      def before_store(command)
        command.instance_exec(@parser, &@opts[:before_store])
      end

      def before_parse?
        @opts.key?(:before_parse) && @opts[:before_parse].respond_to?(:call)
      end

      def before_parse(command)
        command.instance_exec(@parser, &@opts[:before_parse])
      end
    end
  end
end
