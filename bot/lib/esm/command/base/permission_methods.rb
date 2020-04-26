# frozen_string_literal: true

module ESM
  module Command
    class Base
      module PermissionMethods
        def command_enabled?
          @command_enabled
        end

        def command_whitelisted?
          return @command_whitelisted if !@command_whitelisted.nil?
          return true if !@whitelist_enabled

          community = target_community || current_community
          return false if community.nil?

          server = ESM.bot.servers[community.guild_id.to_i]
          guild_member = current_user.on(server)
          return false if guild_member.nil?

          @command_whitelisted =
            if guild_member.permission?(:administrator)
              true
            elsif @whitelisted_role_ids.empty?
              false
            else
              @whitelisted_role_ids.any? { |role_id| guild_member.role?(role_id.to_i) }
            end

          @command_whitelisted
        end

        # Is the command allowed in this channel?
        # @note: Purposefully explicit
        def command_allowed?
          text_channel = @event.channel.text?

          # Not allowed to use if sent in text channel and the command isn't allowed in text channels
          return false if text_channel && !@command_allowed

          # Allowed to use if sent in text channel and the command is allowed in text channels
          return true if text_channel && @command_allowed

          # Allowed to use if sent in PM and the command isn't allowed in text channels
          return true if !text_channel && !@command_allowed

          # Allowed to use if sent in PM and the command is allowed in text channels
          return true if !text_channel && @command_allowed
        end
      end
    end
  end
end
