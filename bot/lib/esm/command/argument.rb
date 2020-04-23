# frozen_string_literal: true

module ESM
  module Command
    class Argument
      # argument :name, regex: /xxx/, preserve: true, type: :integer, display_as: "", multiline: true, default: nil
      attr_accessor :value
      attr_reader :name

      def initialize(name, opts = {})
        @name = name
        @opts = load_options(opts)

        # Run some checks on the argument
        check_for_regex!
        check_for_description!
      end

      def regex
        @opts[:regex]
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

      def default
        @opts[:default]
      end

      def default?
        !default.blank?
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

      private

      def defaults
        @defaults ||= {
          community_id: {
            regex: ESM::Regex::COMMUNITY_ID,
            description: "default_arguments.community_id"
          },
          target: {
            regex: ESM::Regex::TARGET,
            description: "default_arguments.target"
          },
          server_id: {
            regex: ESM::Regex::SERVER_ID,
            description: "default_arguments.server_id"
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
    end
  end
end
