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
