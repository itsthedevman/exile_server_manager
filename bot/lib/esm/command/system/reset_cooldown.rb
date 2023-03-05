# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module System
      class ResetCooldown < ESM::Command::Base
        set_type :admin
        register_aliases :resetcooldown
        limit_to :text
        requires :registration

        # Skip checking for the server since this is not dependent on the server being online.
        skip_check :connected_server

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :target, default: nil
        argument :command_name,
          regex: /\w+/,
          description: "commands.reset_cooldown.arguments.command_name",
          default: nil,
          before_store: lambda { |parser|
            return if parser.value.nil?
            return if ESM::Command.include?(parser.value)

            # This allows "passing" the value for the command_name argument onto the server_id argument.
            parser.argument.skip_removal = true
            parser.value = nil
          }
        argument :server_id, default: nil

        def on_execute
          @checks.owned_server! if @arguments.server_id
          check_for_valid_command!
          @checks.registered_target_user! if target_user

          # Send the confirmation request
          reply(confirmation_embed)
          response = ESM.bot.await_response(current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          return reply(I18n.t("commands.reset_cooldown.cancellation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase

          # Reset all cooldowns for that user.
          cooldown_query.each(&:reset!)

          # Send the success message
          reply(success_embed)
        end

        def check_for_valid_command!
          return if @arguments.command_name.nil?
          return if ESM::Command.include?(@arguments.command_name)

          check_failed!(:invalid_command, user: current_user.mention, command_name: @arguments.command_name)
        end

        def confirmation_embed
          namespace_prefix = "commands.reset_cooldown.confirmation_embed"
          ESM::Embed.build do |e|
            e.title = I18n.t("#{namespace_prefix}.title")
            description = I18n.t("#{namespace_prefix}.description.base", user: current_user.mention)

            # Change the description based on what's been requested
            # User
            description +=
              if target_user
                I18n.t("#{namespace_prefix}.description.one_user", target_user: target_user.mention)
              else
                I18n.t("#{namespace_prefix}.description.all_users")
              end

            # Command
            description +=
              if @arguments.command_name
                I18n.t("#{namespace_prefix}.description.one_command", command_name: @arguments.command_name)
              else
                I18n.t("#{namespace_prefix}.description.all_commands")
              end

            # Server
            description +=
              if @arguments.server_id
                I18n.t("#{namespace_prefix}.description.one_server", server_id: @arguments.server_id)
              else
                I18n.t("#{namespace_prefix}.description.all_servers")
              end

            e.description = description
            e.add_field(name: I18n.t("#{namespace_prefix}.field_name"), value: I18n.t("#{namespace_prefix}.field_value"))
          end
        end

        def cooldown_query
          query = ESM::Cooldown.where(community_id: current_community.id)
          query = query.or(ESM::Cooldown.where(user_id: target_user.esm_user.id, steam_uid: target_user.steam_uid)) if target_user

          # Check for command_name and/or server_id if we've been given one
          query = query.where(command_name: @arguments.command_name) if !@arguments.command_name.nil?
          query = query.where(server_id: target_server.id) if !@arguments.server_id.nil?

          query
        end

        def success_embed
          namespace_prefix = "commands.reset_cooldown.success_embed"

          ESM::Embed.build do |e|
            description = I18n.t("#{namespace_prefix}.description.base", user: current_user.mention)

            # Change the description based on what's been requested
            # User
            description +=
              if target_user
                I18n.t("#{namespace_prefix}.description.one_user", target_user: target_user.mention)
              else
                I18n.t("#{namespace_prefix}.description.all_users")
              end

            # Command
            description +=
              if @arguments.command_name
                I18n.t("#{namespace_prefix}.description.one_command", command_name: @arguments.command_name)
              else
                I18n.t("#{namespace_prefix}.description.all_commands")
              end

            # Server
            description +=
              if @arguments.server_id
                I18n.t("#{namespace_prefix}.description.one_server", server_id: @arguments.server_id)
              else
                I18n.t("#{namespace_prefix}.description.all_servers")
              end

            e.description = description
            e.color = :green
          end
        end
      end
    end
  end
end
