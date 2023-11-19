# frozen_string_literal: true

module ESM
  module Command
    class Base
      # Methods involved with defining or creating a Command for ESM
      module Definition
        extend ActiveSupport::Concern

        class Attribute < Struct.new(:modifiable, :default)
          attr_predicate :modifiable

          def initialize(modifiable: true, default: nil)
            super(modifiable: modifiable, default: default)
          end

          def default?
            return false if default.nil?

            !!default
          end
        end

        included do
          class_attribute :abstract_class
          class_attribute :arguments
          class_attribute :attributes
          class_attribute :category
          class_attribute :command_name
          class_attribute :description
          class_attribute :description_extra
          class_attribute :examples_raw
          class_attribute :limited_to
          class_attribute :namespace
          class_attribute :requirements
          class_attribute :skipped_actions
          class_attribute :type
        end

        class_methods do
          #
          # Defines an argument for this command
          #
          # @param name [Symbol] The name of the argument
          # @param type [Symbol] The Discord argument type (defaults to string in Argument)
          # @param **opts [Hash] See ESM::Command::Argument#initialize
          #
          def argument(name, type = nil, **opts)
            arguments[name] = Argument.new(name, type, opts.merge(command_class: self))
            self
          end

          #
          # Sets the command's type. Commonly :admin, :player, or :development
          #
          # @param type [Symbol, String]
          #
          def command_type(type)
            self.type = type.to_sym
            self
          end

          #
          # Limits the command to a particular channel type.
          #
          # @param channel_type [Symbol, String] Valid options: :text, :pm
          #
          def limit_to(channel_type)
            if TEXT_CHANNEL_TYPES.include?(channel_type)
              self.limited_to = :text
            elsif DM_CHANNEL_TYPES.include?(channel_type)
              self.limited_to = :dm
            else
              raise ArgumentError,
                "Invalid channel type for #{self.class.name}.limit_to(:#{channel_type}). Expected one of: #{CHANNEL_TYPES}"
            end

            self
          end

          #
          # Changes an attribute on the command. These are used mainly for permissions
          #
          # @param attribute [Symbol, String] The name of the attribute
          # @param **opts [Hash] Configuration options. See ESM::Command::Attribute
          #
          def change_attribute(attribute, **opts)
            if !attributes.key?(attribute)
              raise ArgumentError, "Invalid attribute provided: #{attribute}. Expected one of: #{attributes.keys}"
            end

            attribute = attributes[attribute]
            opts.each { |k, v| attribute.send("#{k}=", v) }
            self
          end

          #
          # Sets a list of requirements for the command
          #
          # @param *keys [Symbol] The requirements. Valid options: :registration, :dev
          #
          def requires(*)
            requirements.set(*)
            self
          end

          def does_not_require(*)
            requirements.unset(*)
            self
          end

          #
          # A list of check names that should be skipped during the lifecycle
          #
          # @param *actions [Array<Symbol>] The name of the actions to skip
          #
          def skip_action(*)
            skipped_actions.set(*)
            self
          end

          alias_method :skip_actions, :skip_action

          #
          # Sets the command's namespace
          # When registered with Discord, each namespace is converted to: /<segments...> <command_name>
          #
          # @param *segments [Array<Symbol>] The individual segments
          # @param command_name [Symbol] The command name. Defaults to the result from `#command_name`
          #
          def command_namespace(*segments, command_name: self.command_name)
            raise ESM::Exception::InvalidCommandNamespace, "#{name}#command_namespace - Discord only supports one subgroup per command" if segments.size > 2

            self.namespace = {
              segments: segments.presence || [],
              command_name: command_name.to_sym
            }

            self
          end

          #
          # Adds the root namespace (/<command_name>) to this command
          #
          alias_method :use_root_namespace, :command_namespace

          #
          # Returns a hash representation of this command
          #
          # @return [Hash]
          #
          def to_h
            {
              name: command_name,
              type: type,
              category: category,
              namespace: namespace,
              limited_to: limited_to,
              attributes: attributes,
              requirements: requirements.to_h,
              skipped_actions: skipped_actions.to_h,
              arguments: arguments,
              description: description,
              description_extra: description_extra,
              examples: examples_raw
            }
          end

          def to_details
            details = to_h.except(:skipped_actions, :namespace)

            details[:usage] = usage(with_args: false)

            details[:arguments] = details[:arguments].each_with_object({}) do |(name, argument), hash|
              hash[argument.display_name] = argument
            end

            details[:description] = details[:description].then do |description|
              if (description_extra = details.delete(:description_extra).presence)
                description += "\n#{description_extra}"
              end

              description
            end

            details.transform_keys { |k| "command_#{k}" }
          end

          #
          # Returns the JSON representation of this command
          #
          # @return [String]
          #
          def to_json(...)
            to_h.to_json(...)
          end

          #
          # Returns the command's examples as a string, by default
          #
          # @param raw [TrueClass, FalseClass] True for the raw hash, false for a string. Default: false
          #
          def examples(raw: false)
            return examples_raw if raw

            examples_raw.format(join_with: "\n") do |example|
              <<~STRING
                ```
                #{usage(with_args: true, arguments: example[:arguments] || {})}
                ```#{example[:description]}
              STRING
            end
          end

          # @!visibility private
          def inherited(child_class)
            child_class.__disconnect_variables!
            super
          end

          # @!visibility private
          def __disconnect_variables!
            self.abstract_class = false
            self.arguments = {}

            self.attributes = {
              enabled: Attribute.new(default: true),
              allowlist_enabled: Attribute.new(default: false),
              allowlisted_role_ids: Attribute.new(default: []),
              allowed_in_text_channels: Attribute.new(default: true),
              cooldown_time: Attribute.new(default: 2.seconds)
            }

            # ESM::Command::Territory::SetId => set_id
            self.command_name = name.demodulize.underscore.downcase

            # ESM::Command::Request::Accept => system
            self.category = module_parent.name.demodulize.downcase

            command_namespace(category.to_sym) # Sets the default namespace to be: /<category> <command_name>

            self.description = I18n.t("commands.#{command_name}.description", default: "")
            self.description_extra = I18n.t("commands.#{command_name}.description_extra", default: nil)
            self.examples_raw = I18n.t("commands.#{command_name}.examples", default: [])

            self.limited_to = nil
            self.type = :player
            self.requirements = Inquirer.new(:dev, :registration)

            # Require registration by default
            requirements.set(:registration)

            self.skipped_actions = Inquirer.new(
              :connected_server, :cooldown, :nil_target_user,
              :nil_target_server, :nil_target_community, :different_community
            )
          end

          # @!visibility private
          def register_root_command(community_discord_id, command_name)
            check_for_valid_configuration!

            ::ESM.bot.register_application_command(
              command_name,
              description,
              server_id: community_discord_id
            ) do |builder, _permission_builder|
              register_arguments(builder)
            end
          end

          # @!visibility private
          def register_subcommand(builder, command_name)
            check_for_valid_configuration!

            builder.subcommand(command_name.to_sym, description, &method(:register_arguments))
          end

          # @!visibility private
          def register_arguments(builder)
            # Required arguments must be first (Discord requirement)
            sorted_arguments = arguments.values.sort_by { |argument| argument.required_by_discord? ? 0 : 1 }

            sorted_arguments.each do |argument|
              if !builder.respond_to?(argument.type)
                raise ESM::Exception::InvalidCommandArgument, "Invalid type provided for argument #{argument.to_h}"
              end

              info!(
                command: usage(with_args: false),
                argument: {name: argument.name, type: argument.type}
              )

              builder.public_send(
                argument.type,
                argument.display_name,
                argument.description,
                **argument.options
              )
            end

            info!(command: usage(with_args: false), status: :registered)
          end

          # @!visibility private
          def check_for_valid_configuration!
            return if abstract_class

            if description.length > 100
              raise ArgumentError, "#{name} - description cannot be longer than 100 characters"
            end

            if description.length < 1
              raise ArgumentError, "#{name} - description must be at least 1 character long"
            end
          end
        end

        ############################################################
        ############################################################

        attr_reader :response # v1
        attr_reader :name, :category, :cooldown_time, :permissions, :timers, :event

        attr_accessor :current_community, :current_user, :current_channel

        delegate :examples, to: "self.class"

        def initialize(user: nil, server: nil, channel: nil, arguments: {})
          command_class = self.class

          @name = command_class.command_name
          @category = command_class.category
          @attributes = attributes.to_istruct

          @current_user = ESM::User.from_discord(user)
          @current_community = ESM::Community.from_discord(server)
          @current_channel = channel
          @arguments = ESM::Command::Arguments.new(self, templates: command_class.arguments, values: arguments)

          @timers = Timers.new(name)

          debug!(
            command_name: name,
            user: user&.attributes,
            server: server&.attributes,
            channel: channel&.attributes,
            arguments: self.arguments
          )
        end
      end
    end
  end
end
