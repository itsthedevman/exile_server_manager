# frozen_string_literal: true

module ESM
  module Command
    CATEGORIES = %w[development general server community entertainment system].freeze

    @all = []
    @by_category = nil
    @by_type = nil
    @caches = []

    class << self
      attr_reader :all
    end

    def self.[](command_name)
      return if command_name.blank?

      @all.find { |command| command_name == command.name || command.command_aliases.include?(command_name.to_sym) }
    end

    def self.include?(command_name)
      return false if command_name.blank?

      @all.any? { |command| command_name == command.name || command.command_aliases.include?(command_name.to_sym) }
    end

    def self.load_commands
      path = File.expand_path("lib/esm/command")
      CATEGORIES.each do |category|
        Dir["#{path}/#{category}/*.rb"].each do |command_path|
          process_command(command_path, category)
        end
      end

      # Lock it!
      @all = @all.freeze if !ESM.env.test?

      # Remove all the caches since this will recache
      ESM::CommandCache.in_batches(of: 10_000).delete_all

      # Store the caches in the DB so the website can read this data
      ESM::CommandCache.import(@caches)
    end

    def self.process_command(command_path, category)
      command_name = parse_command_name_from_path(command_path)

      # Create our command to be stored
      command = build(command_name, category)

      # Tell the bot about our command
      define(command)

      # Cache Command
      cache(command)
    end

    def self.parse_command_name_from_path(command_path)
      command_path.gsub("#{File.expand_path("..", command_path)}/", "").gsub(/\.rb$/, "")
    end

    def self.build(command_name, category)
      # set_id -> SetId or pay -> Pay
      command_name = command_name.classify(keep_plural: true)
      category = category.classify(keep_plural: true)

      # "ESM::Command::Server::Pay" -> ESM::Command::Server::Pay -> New instance
      "ESM::Command::#{category}::#{command_name}".constantize.new
    end

    def self.define(command)
      ESM.bot.command(command.name.to_sym, aliases: command.aliases) do |event|
        # Execute the command.
        # Threaded since I handle everything in the commands
        Thread.new { command.execute(event) }

        # Don't send anything back
        nil
      end
    end

    def self.cache(command)
      # Background commands do not have types
      return if command.type.nil?

      # Use command_name instead of command.name to get set_id instead of setid
      @all << command.class

      # Don't cache development commands
      return if command.type == :development

      # To be written to the DB in bulk
      @caches << {
        command_name: command.name,
        command_category: command.category,
        command_description: command.description,
        command_example: command.example,
        command_usage: command.arguments.map(&:to_s).join(" "),
        command_arguments: command.arguments.to_s,
        command_aliases: command.aliases,
        command_defines: command.defines.to_h
      }
    end

    def self.by_category
      @by_category ||= OpenStruct.new(@all.group_by(&:category.downcase))
    end

    def self.by_type
      @by_type ||= OpenStruct.new(@all.group_by(&:command_type))
    end

    def self.create_configurations_for_community(community)
      configurations =
        @all.map do |command|
          # Converts 2.seconds to [2, "seconds"]
          cooldown_quantity, cooldown_type = command.defines.cooldown_time.default.parts.map { |type, length| [length, type.to_s] }.first

          {
            community_id: community.id,
            command_name: command.name,
            enabled: command.defines.enabled.default,
            cooldown_quantity: cooldown_quantity,
            cooldown_type: cooldown_type,
            allowed_in_text_channels: command.defines.allowed_in_text_channels.default,
            whitelist_enabled: command.defines.whitelist_enabled.default,
            whitelisted_role_ids: command.defines.whitelisted_role_ids.default
          }
        end

      ESM::CommandConfiguration.import(configurations)
    end
  end
end
