# frozen_string_literal: true

module ESM
  module Command
    module General
      class Help < ESM::Command::Base
        type :player
        aliases :commands
        argument :category, regex: /.*/, default: nil, description: t("commands.help.arguments.category")

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        def discord
          if @arguments.category == "commands"
            commands
          elsif ESM::Command.include?(@arguments.category)
            command
          else
            getting_started
          end
        end

        #########################
        # Command Methods
        #########################
        def getting_started
          ESM::Embed.build do |embed|
            embed.title = t("commands.help.getting_started.title", user: @event.author.username)
            embed.description = t("commands.help.getting_started.description")

            embed.add_field(
              name: t("commands.help.categories.name"),
              value: t("commands.help.categories.value")
            )
          end
        end

        def commands
          ESM::Embed.build do |embed|
            embed.title = t("commands.help.commands.title")
            embed.description = t("commands.help.commands.description", prefix: ESM.bot.prefix)

            types = %i[player admin]
            types << :development if ESM.env.development?

            # Remove :admin if player mode is enabled for this community
            types.remove(:admin) if current_community&.player_mode_enabled?

            # Now build the embed
            types.each do |type|
              next if categories(type).blank?

              embed.add_field(value: t("commands.help.commands.#{type}_commands_title"))
              categories(type).each do |category, commands|
                embed.add_field(
                  name: category.humanize,
                  value: format_commands(commands)
                )
              end
            end
          end
        end

        def categories(type)
          return [] if ESM::Command.by_type[type].nil?

          ESM::Command.by_type[type].group_by(&:category)
        end

        def format_commands(commands)
          commands.format do |command|
            "**`#{ESM.bot.prefix}#{command.name}`**: #{command.description}\n"
          end
        end

        def command
          command = ESM::Command[@arguments.category]

          ESM::Embed.build do |embed|
            embed.title = t("commands.help.command.title", name: command.name)
            embed.description = command.description

            # Usage
            embed.add_field(
              name: t("commands.help.command.usage"),
              value: "```#{command.usage}```"
            )

            # Arguments
            if command.arguments.present?
              embed.add_field(
                name: t("commands.help.command.arguments"),
                value: command.arguments
              )
            end

            # Examples
            if command.examples.present?
              embed.add_field(
                name: t("commands.help.command.examples"),
                value: command.examples
              )
            end
          end
        end
      end
    end
  end
end
