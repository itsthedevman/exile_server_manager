# frozen_string_literal: true

require "esm/command/base"
require "esm/command/categories"
require "esm/command/cache"
require "esm/command/argument"
require "esm/command/argument_container"

module ESM
  module Command
    CATEGORIES = %w[development general server community entertainment].freeze

    class << self
      attr_reader :all
    end

    def self.build!
      @all = []
      @by_category = nil
      @by_type = nil

      load_commands
    end

    def self.[](command_name)
      @all.find { |command| command.name == command_name }
    end

    def self.include?(command_name)
      @all.any? { |command| command_name == command.name }
    end

    def self.load_commands
      path = File.expand_path("lib/esm/command")
      CATEGORIES.each do |category|
        Dir["#{path}/#{category}/*.rb"].each do |command_path|
          process_command(command_path, category)
        end
      end

      # Lock it!
      @all = @all.freeze
    end

    def self.process_command(command_path, category)
      require command_path
      command_name = parse_command_name_from_path(command_path)

      # Create our command to be stored
      command = build(command_name, category)

      # Tell the bot about our command
      define(command)

      # Cache Command
      cache(command, category)
    end

    def self.parse_command_name_from_path(command_path)
      command_path.gsub("#{File.expand_path("..", command_path)}/", "").gsub(/\.rb$/, "")
    end

    def self.build(command_name, category)
      "ESM::Command::#{category.camelize}::#{command_name.camelize}".constantize.new
    end

    def self.define(command)
      ESM.bot.command(command.name.to_sym, aliases: command.aliases) do |event|
        # Execute the command
        execute(event, command)
      end
    end

    def self.cache(command, category)
      # Background commands do not have types
      return if command.type.nil?

      @all << ESM::Command::Cache.new(
        name: command.name,
        type: command.type,
        category: category,
        description: command.description,
        arguments: command.arguments.to_s,
        examples: command.example,
        usage: command.usage,
        defines: command.defines
      )
    end

    def self.execute(event, command)
      # Create a new instance of the command so values are not shared across players
      command = command.class.new

      # Execute and handle any errors
      begin
        result = command.execute(event)
      rescue ESM::Exception::DataError => e
        result = e.data
      rescue StandardError => e
        result =
          if ESM.env.development?
            "Exception:\n```#{e.message}```\nBacktrace\n```#{e.backtrace}```"
          else
            e.message
          end
      end

      # Cleanup result and send
      send_result(result, event)
    end

    def self.send_result(result, event)
      message = nil

      case result
      when ESM::Exception::Error
        message = result.message
      when ESM::Exception::DataError
        message = result.data
      when ::Exception
        message = t("exceptions.system", message: result.message)
      when String, ESM::Embed
        message = result
      else
        # This allows me to not have to explicitly return nil from my commands
        return nil
      end

      return message if ESM.env.test?

      ESM.bot.deliver(message, to: event.channel)

      # Since this actually gets called by Discordrb, we want to return nil
      nil
    end

    def self.by_category
      @by_category ||= @all.group_by(&:category).to_ostruct
    end

    def self.by_type
      @by_type ||= @all.group_by(&:type).to_ostruct
    end

    def self.create_configurations_for_community(community)
      @all.each do |command|
        # Converts 2.seconds to [2, "seconds"]
        cooldown_quantity, cooldown_type = command.defines.cooldown_time.default.parts.map { |type, length| [length, type.to_s] }.first

        configuration =
          ESM::CommandConfiguration.create!(
            community_id: community.id,
            command_name: command.name,
            enabled: command.defines.enabled.default,
            cooldown_quantity: cooldown_quantity,
            cooldown_type: cooldown_type,
            allowed_in_text_channels: command.defines.allowed_in_text_channels.default,
            whitelist_enabled: command.defines.whitelist_enabled.default,
            whitelisted_role_ids: command.defines.whitelisted_role_ids.default
          )

        community.command_configurations << configuration
      end
    end
  end
end
