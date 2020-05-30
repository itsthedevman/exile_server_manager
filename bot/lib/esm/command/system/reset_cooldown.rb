# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module System
      class ResetCooldown < ESM::Command::Base
        type :admin
        aliases :resetcooldown
        limit_to :text
        requires :registration
        skip_check :connected_server

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :target
        argument :command_name, regex: /[\w]+/, description: "commands.reset_cooldown.arguments.command_name", default: nil
        argument :server_id, default: nil

        def discord
          @checks.owned_server! if @arguments.server_id
          check_for_valid_command!

          # Send the confirmation request
          response = ESM.bot.deliver_and_await!(confirmation_embed, to: current_channel, owner: current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          return reply(I18n.t("commands.reset_cooldown.cancelation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase

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
          ESM::Embed.build do |e|
            e.title = I18n.t("commands.reset_cooldown.confirmation_embed.title")
            description = I18n.t("commands.reset_cooldown.confirmation_embed.description.base", user: current_user.mention, target_user: target_user.mention)

            # Change the description based on what's been requested
            description +=
              if !@arguments.command_name.nil? && !@arguments.server_id.nil?
                I18n.t("commands.reset_cooldown.confirmation_embed.description.with_name_and_server", command_name: @arguments.command_name, server_id: target_server.server_id)
              elsif !@arguments.command_name.nil?
                I18n.t("commands.reset_cooldown.confirmation_embed.description.with_command_name", command_name: @arguments.command_name)
              else
                I18n.t("commands.reset_cooldown.confirmation_embed.description.all")
              end

            e.description = description
            e.add_field(name: I18n.t("commands.reset_cooldown.confirmation_embed.field_name"), value: I18n.t("commands.broadcast.confirmation_embed.field_value"))
          end
        end

        def cooldown_query
          query = ESM::Cooldown.where(user_id: target_user.esm_user.id, community_id: current_community.id)

          # Check for command_name and/or server_id if we've been given one
          query = query.where(command_name: @arguments.command_name) if !@arguments.command_name.nil?
          query = query.where(server_id: target_server.id) if !@arguments.server_id.nil?

          query
        end

        def success_embed
          ESM::Embed.build do |e|
            description = I18n.t("commands.reset_cooldown.success_embed.description.base", user: current_user.mention, target_user: target_user.mention)

            # Change the description based on what's been requested
            description +=
              if !@arguments.command_name.nil? && !@arguments.server_id.nil?
                I18n.t("commands.reset_cooldown.success_embed.description.with_name_and_server", command_name: @arguments.command_name, server_id: target_server.server_id)
              elsif !@arguments.command_name.nil?
                I18n.t("commands.reset_cooldown.success_embed.description.with_command_name", command_name: @arguments.command_name)
              else
                I18n.t("commands.reset_cooldown.success_embed.description.all")
              end

            e.description = description
            e.color = :green
          end
        end
      end
    end
  end
end
