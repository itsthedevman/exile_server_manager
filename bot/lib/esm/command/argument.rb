# frozen_string_literal: true

module ESM
  module Command
    class Argument
      #
      # Global default values for all argument
      # You may overwrite these in your argument definition
      #
      DEFAULT_TEMPLATE = {
        checked_against: :present?,
        checked_against_if: lambda do |argument, content|
          argument.required? || content.present?
        end
      }.freeze

      #
      # Global templates for any argument to use
      # These can be used by defining an argument with the same name,
      # or by providing the `:template` option during argument definition
      #
      TEMPLATES = {
        # Required: Majority of the time, this is needed.
        target: {
          checked_against: ESM::Regex::TARGET,
          description_extra: "commands.arguments.target.description_extra",
          description: "commands.arguments.target.description",
          required: true
        },

        # Required: Majority of the time, this is needed.
        command: {
          checked_against: ->(content) { ESM::Command.include?(content) },
          description: "commands.arguments.command.description",
          required: true
        },

        # Required: No functionality to "guess" this
        territory_id: {
          checked_against: ESM::Regex::TERRITORY_ID,
          description_extra: "commands.arguments.territory_id.description_extra",
          description: "commands.arguments.territory_id.description",
          required: true,
          placeholder: "territory"
        },

        # Optional in Discord: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        # Required: In the bot
        community_id: {
          required: {discord: false, bot: true},
          checked_against: ESM::Regex::COMMUNITY_ID,
          description_extra: "commands.arguments.community_id.description_extra",
          description: "commands.arguments.community_id.description",
          optional_text: "commands.arguments.community_id.optional_text",
          placeholder: "community",
          modifier: lambda do |content|
            if content.present?
              # User alias
              if (id_alias = current_user.id_aliases.find_community_alias(content))
                content = id_alias.community.community_id
              end

              return content
            end

            # content == nil, attempt to find and use a default
            user_defaults = current_user.id_defaults
            return user_defaults.community.community_id if user_defaults.community_id

            # Community autofill
            return current_community.community_id if current_channel.text?

            nil
          end
        },

        # Optional in Discord: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        # Required: In the bot
        server_id: {
          required: {discord: false, bot: true},
          checked_against: ESM::Regex::SERVER_ID,
          description_extra: "commands.arguments.server_id.description_extra",
          description: "commands.arguments.server_id.description",
          optional_text: "commands.arguments.server_id.optional_text",
          placeholder: "server",
          modifier: lambda do |content|
            if content.present?
              # User provided - Starts with a community ID
              return content if content.match("#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

              # User alias
              if (id_alias = current_user.id_aliases.find_server_alias(content))
                return id_alias.server.server_id
              end

              # Community autofill
              if current_channel.text? && current_community.servers.by_server_id_fuzzy(content).any?
                return "#{current_community.community_id}_#{content}"
              end

              return content
            end

            # content == nil, attempt to find and use a default
            if current_channel.text?
              channel_default = current_community.id_defaults.for_channel(current_channel)
              return channel_default.server.server_id if channel_default&.server_id

              global_default = current_community.id_defaults.global
              return global_default.server.server_id if global_default&.server_id
            end

            if current_user.id_defaults.server_id
              user_defaults = current_user.id_defaults
              return user_defaults.server.server_id if user_defaults.server_id
            end

            nil
          end
        }
      }.freeze

      attr_reader :name, :type, :discord_type,
        :display_name, :command_class, :command_name,
        :default_value, :modifier, :placeholder,
        :description, :description_extra, :optional_text,
        :options, :checked_against, :checked_against_if

      #
      # A configurable representation of a command argument
      #
      # @param name [Symbol, String]
      #     The argument's name
      #
      # @param type [Symbol, String]
      #     The argument's type (directly linked to Discord).
      #     Optional.
      #     Default: :string
      #
      # @param opts [Hash]
      #     Options to configure the argument
      #
      #   @option opts [TrueClass, FalseClass, Hash] :required
      #     Controls if the argument should be required by Discord and by the Bot
      #     Fine grain control can be achieved by providing a Hash.
      #     For example, not require an argument on Discord but require it on the bot side
      #       required: {discord: false, bot: true}
      #     Optional. Default: false
      #
      #   @option opts [Symbol, String, nil] :template
      #     The name of a default entry in which `opts` are merged into.
      #     Useful for having an argument that acts like another argument, but may have different configuration
      #
      #   @option opts [String] :description
      #     This argument's description, in less than 100 characters.
      #       This description is used in Discord when viewing the argument.
      #       Note: Providing this option is optional, however, all arguments MUST have a non-blank description
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.description
      #
      #   @option opts [String] :description_extra
      #     Any extra information to be included that wouldn't fit in the 100 character limit
      #       Note: Providing this option is optional, however, this argument MUST have a non-blank description
      #       This description is used in the help documentation with the help command and on the website
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.description_extra
      #
      #   @option opts [String] :optional_text
      #     Allows for overriding the "this argument is optional" text in the help documentation.
      #       This opt is ignored if `required: true`
      #     Optional.
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.optional_text
      #
      #   @option opts [Symbol, String] :display_name
      #     Changes how the argument is displayed to the user, but not in the code
      #     Optional.
      #
      #   @option opts [Object] :default
      #     The default value if this argument. This value is ignored if `required: true`
      #     Optional.
      #     Default: nil
      #
      #   @option opts [Boolean] :preserve_case
      #     Controls if this argument's value should be converted to lowercase or not.
      #     Optional.
      #     Default: false
      #
      #   @option opts [Proc] :modifier
      #     A block of code used to modify this argument's value before validation
      #     Optional.
      #
      #   @option opts [Hash] :choices
      #     The key: display_value of choices the user can pick from
      #     Optional.
      #
      #   @option opts [Integer] :min_value
      #     If type is integer/number, this is the minimum value that can be selected
      #
      #   @option opts [Integer] :max_value
      #     If type is integer/number, this is the maximum value that can be selected
      #
      #   @option opts [Regex, String, Proc, Array] :checked_against
      #     Used to perform validation against the content provided to the argument
      #     Regex/String  - Content must `match?`
      #     Proc          - Content is passed in and can return a truthy value to consider the content as valid
      #     Array         - Content must be one of the values
      #
      #   @option opts [Proc] :checked_against_if
      #     Used to determine if the argument should be validated against :checked_against.
      #     Can return a truthy value to continue to validation. Falsey values will cause validation to be skipped
      #
      #   @option opts [String, Symbol] :placeholder
      #     Used when the command usage is displayed and use_placeholders are true. Defaults to the display name
      def initialize(name, type = nil, opts = {})
        template_name = (opts[:template] || name).to_sym

        # Precedence:
        #   opts -> template -> default template
        opts = DEFAULT_TEMPLATE.merge(TEMPLATES[template_name] || {}).merge(opts)

        @name = name
        @type = type ? type.to_sym : :string
        @discord_type = Discordrb::Interactions::OptionBuilder::TYPES[@type]
        @display_name = (opts[:display_name] || name).to_sym
        @command_class = opts[:command_class]
        @command_name = command_class.command_name.to_sym

        @default_value = opts[:default]
        @preserve_case = !!opts[:preserve_case]
        @modifier = opts[:modifier]
        @checked_against = opts[:checked_against]
        @checked_against_if = opts[:checked_against_if]
        @placeholder = opts[:placeholder].presence || name

        if opts[:required].is_a?(Hash)
          @required_by_discord = !!opts.dig(:required, :discord)
          @required_by_bot = !!opts.dig(:required, :bot)
        else
          required = !!opts[:required]
          @required_by_discord = required
          @required_by_bot = required
        end

        @options = {required: @required_by_discord}
        @options[:min_value] = opts[:min_value] if opts[:min_value]
        @options[:max_value] = opts[:max_value] if opts[:max_value]

        # I prefer {value: "Display Name"}, Discord/rb wants it to be {"Display Name": "value"}
        if opts[:choices]
          @options[:choices] = opts[:choices].map { |k, v| [v.to_s, k.to_s] }.to_h
        end

        @description = load_locale_or_provided(opts[:description], "description")
        @description_extra = load_locale_or_provided(opts[:description_extra], "description_extra").presence
        @optional_text = load_optional_text(opts[:optional_text])

        check_for_valid_configuration!
      end

      def transform_and_validate!(input, command)
        raise ArgumentError, "Invalid command argument" unless command.is_a?(ApplicationCommand)

        input_present = input.present?
        input = default_value if !input_present && default_value?

        sanitized_content =
          if input.is_a?(String) && input_present
            preserve_case? ? input.strip : input.downcase.strip
          else
            input
          end

        content =
          if modifier?
            command.instance_exec(sanitized_content, &modifier)
          else
            sanitized_content
          end

        debug!(
          argument: to_h.except(:description, :description_extra, :optional_text),
          input: input,
          before: {
            type: sanitized_content.class.name,
            content: sanitized_content
          },
          after: {
            type: content.class.name,
            content: content
          }
        )

        check_for_valid_content!(command, content)

        content
      end

      def preserve_case?
        @preserve_case
      end

      def modifier?
        !!modifier&.respond_to?(:call)
      end

      def default_value?
        !!@default_value
      end

      def required_by_bot?
        @required_by_bot
      end

      def required_by_discord?
        @required_by_discord
      end

      def required?
        required_by_bot? || required_by_discord?
      end

      def optional?
        !required_by_bot? && !required_by_discord?
      end

      def optional_text?
        optional_text.present?
      end

      def to_s
        if display_name.present?
          display_name.to_s
        else
          name.to_s
        end
      end

      def help_documentation
        output = ["**`#{self}:`**", description]
        output << "#{description_extra}." if description_extra.presence
        output << "**Note:** #{optional_text}" if optional_text?
        output.join("\n")
      end

      def to_h
        {
          name: name,
          command_name: command_name,
          display_name: display_name,
          description: description,
          description_extra: description_extra,
          optional_text: optional_text,
          default_value: default_value,
          modifier: modifier,
          checked_against: checked_against,
          preserve_case: preserve_case?,
          discord: @options,
          bot: {
            required: @required_by_bot
          }
        }
      end

      private

      def load_locale_or_provided(path, suffix)
        return "" if path == "" # Allows skipping this process. Validation will still fire

        locale_path = path.presence || "commands.#{command_name}.arguments.#{name}.#{suffix}"
        localized = I18n.translate(locale_path, default: "")

        # Allows not having to provide an I18n path as the description
        if (localized.blank? || localized.starts_with?("translation missing")) && path.present?
          path
        else
          localized
        end
      end

      def load_optional_text(text_or_path)
        return "" unless optional?

        if (text = load_locale_or_provided(text_or_path, "optional_text"))
          return text if text.present?
        end

        text = "This argument is optional#{default_value? ? "" : "."}"
        text += " and it defaults to `#{default_value}`." if default_value?
        text
      end

      def check_for_valid_content!(command, content)
        return if checked_against_if.nil? || checked_against.nil?
        return unless successful_checked_against_if?(command, content)
        return if successful_checked_against?(command, content)

        raise ESM::Exception::InvalidArgument, self
      end

      def check_for_valid_configuration!
        # choices must be hash
        # choice values must be string
        if options.key?(:choices)
          if !options[:choices].is_a?(Hash)
            raise ArgumentError, "#{command_class}:argument.#{name} - choices must be a hash"
          end

          if options[:choices].values.any? { |v| !v.is_a?(String) }
            raise ArgumentError, "#{command_class}:argument.#{name} - choices cannot contain non-string values"
          end
        end

        # min/max values can only be with integer/number type
        if options.key?(:min_value) || options.key?(:max_value)
          if [:integer, :number].exclude?(type)
            raise ArgumentError, "#{command_class}:argument.#{name} - min/max values can only be used with integer or number types"
          end
        end

        if description.length > 100
          raise ArgumentError, "#{command_class}:argument.#{name} - description cannot be longer than 100 characters"
        end

        if description.length < 1
          raise ArgumentError, "#{command_class}:argument.#{name} - description must be at least 1 character long"
        end
      end

      def successful_checked_against_if?(command, content)
        case checked_against_if
        when Proc
          !!command.instance_exec(self, content, &checked_against_if)
        when TrueClass, FalseClass
          checked_against_if
        end
      end

      def successful_checked_against?(command, content)
        case checked_against
        when Regexp, String
          content.to_s.match?(checked_against)
        when Proc
          !!command.instance_exec(content, &checked_against)
        when Array
          checked_against.include?(content)
        when Symbol
          !!content.public_send(checked_against)
        end
      end
    end
  end
end
