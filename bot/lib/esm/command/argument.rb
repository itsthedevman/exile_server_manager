# frozen_string_literal: true

module ESM
  module Command
    class Argument
      # argument :name, regex: /xxx/, preserve: true, type: :integer, display_as: "", multiline: true, default: nil
      attr_accessor :value
      attr_reader :name

      def initialize(name, opts = {})
        opts = default_from_name(opts[:template] || name, opts) if default_argument?(opts[:template] || name)

        raise ESM::Exception::InvalidCommandArgument, "Missing regex for argument :#{name}" if opts[:regex].nil?
        raise ESM::Exception::InvalidCommandArgument, "Missing description for argument :#{name}" if opts[:description].nil?

        @name = name
        @opts = opts
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

      def description
        @opts[:description] ||= ""
      end

      def to_s
        string = "<"
        string += "?" if !required?

        string +=
          if display_as.present?
            display_as
          else
            name.to_s
          end

        string + ">"
      rescue TypeError
        byebug
      end

      private

      def defaults
        @defaults ||= {
          community_id: {
            regex: ESM::Regex::COMMUNITY_ID,
            description: I18n.t("default_arguments.community_id")
          },
          target: {
            regex: ESM::Regex::TARGET,
            description: I18n.t("default_arguments.target")
          },
          server_id: {
            regex: ESM::Regex::SERVER_ID,
            description: I18n.t("default_arguments.server_id")
          },
          territory_id: {
            regex: ESM::Regex::TERRITORY_ID,
            description: I18n.t("default_arguments.territory_id")
          }
        }
      end

      def default_argument?(name)
        defaults.key?(name)
      end

      def default_from_name(name, opts)
        defaults[name].merge(opts)
      end
    end
  end
end
