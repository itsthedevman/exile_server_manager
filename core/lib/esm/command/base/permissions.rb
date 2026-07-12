# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Permissions
        # The shared resolver that decides access from this command's declared configuration. The bot delegates its
        # per-check predicates to it so a website-initiated run of the same command lands on the same answer. Only the
        # allowlist gate needs the caller's Discord role membership, which stays sourced here (see #command_allowed?).
        def permission
          @permission ||= ESM::Command::Permission.new(
            command: self.class,
            user: current_user,
            community: target_community || current_community
          )
        end

        def community_permissions?
          # Caching so if community_permissions returns `nil`, it doesn't hit the database for every call to this method
          @community_permission_predicate ||= !community_permissions.nil?
        end

        def cooldown_time
          permission.cooldown_time
        end

        def command_enabled?
          permission.enabled?
        end

        def notify_when_command_disabled?
          permission.notify_when_disabled?
        end

        def command_allowlist_enabled?
          permission.allowlist_enabled?
        end

        def command_allowed?
          return true if !permission.allowlist_enabled?

          community = target_community || current_community
          return false if community.nil?

          server = ESM.discord_bot.server(community.guild_id.to_i)
          return false if server.nil?

          guild_member = current_user.on(server)
          return false if guild_member.nil?

          permission.allowlisted?(
            role_ids: guild_member.roles.map(&:id),
            administrator: guild_member.permission?(:administrator)
          )
        end

        # Is the command allowed in this text channel?
        def command_allowed_in_channel?
          return true if current_channel.nil? || current_channel.pm?
          return true if current_community&.player_mode_enabled?
          return community_permissions.allowed_in_text_channels? if community_permissions?

          allowed_define = attributes.allowed_in_text_channels
          return allowed_define.default if allowed_define.default?

          true
        end
      end
    end
  end
end
