# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Permissions
        attr_reader :cooldown_time

        def initialize(command)
          @command = command
          @loaded = false
        end

        def load
          return if @loaded

          community = @command.target_community || @command.current_community
          config =
            if community.present?
              CommandConfiguration.where(community_id: community.id, command_name: @command.name).first
            else
              nil
            end

          config_present = config.present?

          @enabled =
            if config_present
              config.enabled?
            else
              @command.defines.enabled.default
            end

          @allowed =
            if config_present
              config.allowed_in_text_channels?
            else
              @command.defines.allowed_in_text_channels.default
            end

          @whitelist_enabled =
            if config_present
              config.whitelist_enabled?
            else
              @command.defines.whitelist_enabled.default
            end

          @whitelisted_role_ids =
            if config_present
              config.whitelisted_role_ids
            else
              @command.defines.whitelisted_role_ids.default
            end

          @cooldown_time =
            if config_present
              # [2, "seconds"] -> 2 seconds
              # Calls .seconds, .days, .months, etc
              config.cooldown_quantity.send(config.cooldown_type)
            else
              @command.defines.cooldown_time.default
            end

          @notify_when_disabled =
            if config_present
              config.notify_when_disabled?
            else
              true
            end

          @loaded = true
        end

        def enabled?
          @enabled
        end

        def notify_when_disabled?
          @notify_when_disabled
        end

        def whitelisted?
          return @whitelisted if !@whitelisted.nil?
          return true if !@whitelist_enabled

          community = @command.target_community || @command.current_community
          return false if community.nil?

          server = ESM.bot.servers[community.guild_id.to_i]
          guild_member = @command.current_user.on(server)
          return false if guild_member.nil?

          @whitelisted =
            if guild_member.permission?(:administrator)
              true
            elsif @whitelisted_role_ids.empty?
              false
            else
              @whitelisted_role_ids.any? { |role_id| guild_member.role?(role_id.to_i) }
            end

          @whitelisted
        end

        # Is the command allowed in this channel?
        # @note: Purposefully explicit
        def allowed?
          text_channel = @command.event.channel.text?

          # Not allowed to use if sent in text channel and the command isn't allowed in text channels
          return false if text_channel && !@allowed

          # Allowed to use if sent in text channel and the command is allowed in text channels
          return true if text_channel && @allowed

          # Allowed to use if sent in PM and the command isn't allowed in text channels
          return true if !text_channel && !@allowed

          # Allowed to use if sent in PM and the command is allowed in text channels
          return true if !text_channel && @allowed
        end
      end
    end
  end
end
