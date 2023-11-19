# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Permissions
        def community_permissions?
          # Caching so if community_permissions returns `nil`, it doesn't hit the database for every call to this method
          @community_permission_predicate ||= !community_permissions.nil?
        end

        def cooldown_time
          if community_permissions?
            # [2, "seconds"] -> 2 seconds
            # Calls .seconds, .days, .months, etc
            community_permissions.cooldown_quantity.send(community_permissions.cooldown_type)
          else
            cooldown_time = attributes.cooldown_time
            cooldown_time.default? ? cooldown_time.default : 2.seconds
          end
        end

        def command_enabled?
          if community_permissions?
            community_permissions.enabled?
          else
            enabled = attributes.enabled
            enabled.default? ? enabled.default : true
          end
        end

        def notify_when_command_disabled?
          if community_permissions?
            community_permissions.notify_when_disabled?
          else
            true
          end
        end

        def command_allowlist_enabled?
          if community_permissions?
            community_permissions.allowlist_enabled?
          else
            allowlist_enabled = attributes.allowlist_enabled
            allowlist_enabled.default? ? allowlist_enabled.default : false
          end
        end

        def command_allowed?
          return true if !command_allowlist_enabled?

          community = target_community || current_community
          return false if community.nil?

          server = ESM.bot.server(community.guild_id.to_i)
          guild_member = current_user.on(server)
          return false if guild_member.nil?

          allowlisted_role_ids =
            if community_permissions?
              community_permissions.allowlisted_role_ids
            else
              attributes.allowlisted_role_ids.default || []
            end

          return true if guild_member.permission?(:administrator)
          return false if allowlisted_role_ids.empty?

          allowlisted_role_ids.any? { |role_id| guild_member.role?(role_id.to_i) }
        end

        # Is the command allowed in this text channel?
        def command_allowed_in_channel?
          return true if current_channel.pm?
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
