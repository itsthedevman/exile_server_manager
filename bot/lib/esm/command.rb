# frozen_string_literal: true

module ESM
  module Command
    CATEGORIES = %w[
      community
      development
      entertainment
      general
      server
      system
    ].freeze

    # @return [Array<Symbol>] A list of publicly available command types.
    #   Any types not in this list will not show up in the help documentation or on the website.
    TYPES = %i[admin player].freeze

    class << self
      attr_reader :all, :by_type, :by_namespace

      delegate :application_command, :register_application_command, to: "::ESM.bot"
    end

    def self.[](command_name)
      return if command_name.blank?

      command_name = command_name.to_s unless command_name.is_a?(String)
      command_name = command_name[1..] if command_name.start_with?("/")

      # Find by name or by its usage
      all.find do |command_class|
        # OG command name check
        next true if command_class.command_name == command_name

        # Slash command usage check
        usage = command_class.usage(with_slash: false, with_args: false)
        next true if usage == command_name

        # Slash command "subgroup" (the last part of the slash usage)
        next true if usage.split(" ").last == command_name
      end
    end

    def self.get(command_name)
      self[command_name]
    end

    def self.admin_commands
      by_type[:admin]
    end

    def self.player_commands
      by_type[:player]
    end

    def self.include?(command_name)
      !self[command_name].nil?
    end

    def self.load
      @all = []
      @by_type = []
      @by_namespace = {}

      commands_needing_cached = []
      ApplicationCommand.subclasses.each do |command_class|
        # Background commands do not have types
        next if command_class.type.nil?

        @all << command_class

        # Build the command structure for both server and global commands
        # Commands must be registered with Discord together if they share the same namespace
        register_namespace(command_class)

        # Only admin and player commands need to be cached
        next unless TYPES.include?(command_class.type)

        # To be written to the DB in bulk
        commands_needing_cached << command_class.to_details
      end

      # Lock it!
      @all.freeze
      @by_type = @all.group_by(&:type).freeze

      # Run some jobs for command
      RebuildCommandCacheJob.perform_async(commands_needing_cached)
      SyncCommandConfigurationsJob.perform_async(nil)
      SyncCommandCountsJob.perform_async(nil)
    end

    #
    # Returns configurations for all commands, often used for database inserts
    #
    # @return [Array<Hash>]
    #
    def self.configurations
      @configurations ||=
        ESM::Command.all.map do |command_class|
          cooldown_default = command_class.attributes[:cooldown_time]&.default || 2.seconds

          case cooldown_default
          when Enumerator, Integer
            cooldown_type = "times"
            cooldown_quantity = cooldown_default.size
          when ActiveSupport::Duration
            # Converts 2.seconds to [:seconds, 2]
            cooldown_type, cooldown_quantity = cooldown_default.parts.to_a.first
          else
            raise TypeError, "Invalid type \"#{cooldown_default.class}\" detected for command #{command.name}'s default cooldown"
          end

          enabled =
            if (define = command_class.attributes[:enabled])
              define.default
            else
              true
            end

          allowed_in_text_channels =
            if (define = command_class.attributes[:allowed_in_text_channels])
              define.default
            else
              true
            end

          allowlist_enabled =
            if (define = command_class.attributes[:allowlist_enabled])
              define.default
            else
              command_class.type == :admin
            end

          allowlisted_role_ids =
            if (define = command_class.attributes[:allowlisted_role_ids])
              define.default
            else
              []
            end

          {
            command_name: command_class.command_name,
            enabled: enabled,
            cooldown_quantity: cooldown_quantity,
            cooldown_type: cooldown_type,
            allowed_in_text_channels: allowed_in_text_channels,
            allowlist_enabled: allowlist_enabled,
            allowlisted_role_ids: allowlisted_role_ids
          }
        end
    end

    #
    # Using the namespaces of the commands, this method registers the event_hook with Discordrb so it's executed
    # when a command event occurs
    #
    def self.setup_event_hooks!
      by_namespace.each do |name, segments_or_command|
        # It's a command and it's at the root level
        if all.include?(segments_or_command)
          application_command(name, &segments_or_command.method(:event_hook))
          next
        end

        # It's a group and it may have subgroups or subcommands
        segments_or_command.each do |sub_name, segments_or_command|
          # It's a command!
          if all.include?(segments_or_command)
            application_command(name).subcommand(sub_name, &segments_or_command.method(:event_hook))
            next
          end

          # It's a group!
          application_command(name).group(sub_name) do |group|
            segments_or_command.each do |command_name, command|
              group.subcommand(command_name, &command.method(:event_hook))
            end
          end
        end
      end

      nil
    end

    #
    # Registers admin and development commands as "server commands" for the community
    # These are only present on the Discord and are not global
    #
    # @param community_discord_id [String, Integer, NilClass] The community's guild ID to register the command to the
    #   the community. Otherwise, it'll register it globally
    #
    def self.register_commands(community_discord_id = nil)
      by_namespace.each do |name, segments_or_command|
        register_command(name, segments_or_command, community_discord_id)
      end

      nil
    end

    # @!visibility private
    def self.register_command(name, segments_or_command, community_discord_id)
      # It's a command and it's at the root level
      if all.include?(segments_or_command)
        segments_or_command.register_root_command(community_discord_id, name)
        return
      end

      # It's a group and it may have subgroups or subcommands
      ::ESM.bot.register_application_command(name, "C - If you are seeing this, something went wrong", server_id: community_discord_id) do |builder|
        segments_or_command.each do |name, segments_or_command|
          # It's a command!
          if all.include?(segments_or_command)
            segments_or_command.register_subcommand(builder, name)
            next
          end

          # It's a group!
          builder.subcommand_group(name, "G - If you are seeing this, something went wrong") do |group_builder|
            segments_or_command.each do |command_name, command|
              command.register_subcommand(group_builder, command_name)
            end
          end
        end
      end
    end

    # @!visibility private
    private_class_method def self.register_namespace(command_class)
      namespace = command_class.namespace
      segments = namespace[:segments]
      command_name = namespace[:command_name]
      current_segment = @by_namespace

      # Discord treats the first segment after the slash as the "command name"
      # Commands may use this as the root namespace (/help, /register)
      # Or this could be a single group (/community <command_name>)
      if (segment = segments.first)
        current_segment = current_segment[segment.to_sym] ||= {}
      end

      # Discord treats this as a "subgroup" after the "command name"
      # Commands may use this as a group namespace (/server admin <command_name>)
      if (segment = segments.second)
        current_segment = current_segment[segment.to_sym] ||= {}
      end

      # Ensure this namespace isn't already used
      if (namespaced_command = current_segment[command_name.to_sym])
        raise ESM::Exception::InvalidCommandNamespace,
          "#{command_class} attempted to bind to the namespace `/#{segments.join(" ")} #{command_name}` which is already bound to #{namespaced_command}"
      end

      # Finally store the command with the final segment (/server admin show)
      current_segment[command_name.to_sym] = command_class
    end
  end
end
