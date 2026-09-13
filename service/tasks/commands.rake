# frozen_string_literal: true

namespace :commands do
  desc "List all available commands with their usage"
  task list: :environment do
    ESM::Command.load

    commands = ESM::Command.all.sort_by(&:command_name).each_with_object({}) do |command, hash|
      hash[command.command_name] = command.usage
    end

    puts JSON.pretty_generate(commands)
  end

  desc "Delete a single Discord command by name (global + every community guild)"
  task :delete, [:name] => :discord_bot do |_task, args|
    name = args[:name].presence
    abort "Usage: rake commands:delete[command_name]" if name.nil?

    remove = lambda do |label, server_id|
      print "  #{label}..."

      matches = ESM.discord_bot.get_application_commands(server_id:).select { |command| command.name == name }

      matches.each(&:delete)
      puts " removed #{matches.size}"
    rescue => e
      puts " skipped (#{e.class}: #{e.message})"
    end

    puts "Deleting '#{name}'..."
    remove.call("global", nil)

    ESM::Community.all.each do |community|
      remove.call(community.community_id, community.guild_id)
    end
  end

  desc "Re-register one Discord command globally, and in any community guild that already has it"
  task :update, [:name] => :discord_bot do |_task, args|
    name = args[:name].presence
    abort "Usage: rake commands:update[command_name]" if name.nil?

    # Discord registers everything under a top-level name as one command, so updating /community reset_cooldown means
    # re-sending all of /community. Registering a name Discord already has overwrites it in place.
    root_name =
      if ESM::Command.by_namespace.key?(name.to_sym)
        name.to_sym
      elsif (command_class = ESM::Command[name])
        (command_class.namespace[:segments].first || command_class.namespace[:command_name]).to_sym
      end

    abort "No command named '#{name}'" if root_name.nil?

    segments_or_command = ESM::Command.by_namespace[root_name]

    update = lambda do |label, server_id|
      print "  #{label}..."

      # A guild without its own copy already uses the global one, and registering there would add a duplicate
      if server_id && ESM.discord_bot.get_application_commands(server_id:).none? { |command| command.name == root_name.to_s }
        puts " not registered here"
        next
      end

      ESM::Command.register_command(root_name, segments_or_command, server_id)
      puts " done"
    rescue => e
      puts " skipped (#{e.class}: #{e.message})"
    end

    puts "Updating '/#{root_name}'..."
    update.call("global", nil)

    ESM::Community.all.each do |community|
      update.call(community.community_id, community.guild_id)
    end
  end

  desc "Delete and re-register all Discord commands"
  task seed: :discord_bot do
    print "Deleting all global commands..."
    ESM.discord_bot.get_application_commands.each(&:delete)
    puts " done"

    ESM::Community.all.each do |community|
      print "  Deleting commands for #{community.community_id}..."
      ESM.discord_bot.get_application_commands(server_id: community.guild_id).each(&:delete)
      puts " done"

      print "  Registering commands for #{community.community_id}..."
      ESM::Command.register_commands(community.guild_id)
      puts " done"
    end

    print "  Registering global commands..."
    ESM::Command.register_commands
    puts " done"
  end
end
