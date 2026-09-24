# frozen_string_literal: true

# Every Discord command is registered globally. A guild copy sits alongside the global one rather than replacing it,
# so registering in a community's guild as well shows every command twice there.
namespace :commands do
  # Discord registers everything under a top-level name as one command, so /community reset_cooldown is registered by
  # sending all of /community.
  resolve_root_name = lambda do |name|
    abort "Usage: rake commands:<task>[command_name]" if name.blank?

    root_name =
      if ESM::Command.by_namespace.key?(name.to_sym)
        name.to_sym
      elsif (command_class = ESM::Command[name])
        (command_class.namespace[:segments].first || command_class.namespace[:command_name]).to_sym
      end

    abort "No command named '#{name}'" if root_name.nil?

    root_name
  end

  registered_globally = lambda do |root_name|
    ESM.discord_bot.get_application_commands.select { |command| command.name == root_name.to_s }
  end

  desc "List all available commands with their usage"
  task list: :environment do
    ESM::Command.load

    commands = ESM::Command.all.sort_by(&:command_name).each_with_object({}) do |command, hash|
      hash[command.command_name] = command.usage
    end

    puts JSON.pretty_generate(commands)
  end

  desc "Register one Discord command that Discord does not have yet"
  task :create, [:name] => :discord_bot do |_task, args|
    root_name = resolve_root_name.call(args[:name])

    if registered_globally.call(root_name).any?
      abort "'/#{root_name}' is already registered. Use rake commands:update[#{root_name}] to change it"
    end

    print "Creating '/#{root_name}'..."
    ESM::Command.register_command(root_name, ESM::Command.by_namespace[root_name], nil)
    puts " done"
  end

  desc "Re-register one Discord command that Discord already has"
  task :update, [:name] => :discord_bot do |_task, args|
    root_name = resolve_root_name.call(args[:name])

    if registered_globally.call(root_name).none?
      abort "'/#{root_name}' is not registered. Use rake commands:create[#{root_name}] to add it"
    end

    # Registering a name Discord already has overwrites it in place
    print "Updating '/#{root_name}'..."
    ESM::Command.register_command(root_name, ESM::Command.by_namespace[root_name], nil)
    puts " done"
  end

  # Taken as Discord has it rather than resolved against the code, since the usual reason to delete a command is that
  # the code no longer has it
  desc "Delete one top-level Discord command by name"
  task :delete, [:name] => :discord_bot do |_task, args|
    name = args[:name].presence
    abort "Usage: rake commands:delete[command_name]" if name.nil?

    print "Deleting '/#{name}'..."
    matches = registered_globally.call(name)
    matches.each(&:delete)
    puts " removed #{matches.size}"
  end

  desc "Delete and re-register all Discord commands"
  task seed: :discord_bot do
    print "Deleting all commands..."
    ESM.discord_bot.get_application_commands.each(&:delete)
    puts " done"

    print "Registering all commands..."
    ESM::Command.register_commands
    puts " done"
  end
end
