# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Permissions
        def initialize(command)
          @command = command
          @config = nil
        end

        def load
          return if @config

          community = @command.target_community || @command.current_community
          if community.nil?
            argument = @command.arguments.get(:server_id) || @command.arguments.get(:community_id)
            @command.arguments.invalid_argument!(argument) if argument&.invalid?
          end

          @config = community&.command_configurations&.where(command_name: @command.name)&.first
        end

        def config_present?
          @config.present?
        end

        def cooldown_time
          if config_present?
            # [2, "seconds"] -> 2 seconds
            # Calls .seconds, .days, .months, etc
            @config.cooldown_quantity.send(@config.cooldown_type)
          else
            @command.defines.cooldown_time.default
          end
        end

        def enabled?
          if config_present?
            @config.enabled?
          else
            @command.defines.enabled.default
          end
        end

        def notify_when_disabled?
          if config_present?
            @config.notify_when_disabled?
          else
            true
          end
        end

        def whitelisted?
          @whitelisted ||= lambda do
            whitelist_enabled = config_present? ? @config.whitelist_enabled? : @command.defines.whitelist_enabled.default
            return true if !whitelist_enabled

            community = @command.target_community || @command.current_community
            return false if community.nil?

            server = ESM.bot.server(community.guild_id.to_i)
            guild_member = @command.current_user.on(server)
            return false if guild_member.nil?

            whitelisted_role_ids = config_present? ? @config.whitelisted_role_ids : @command.defines.whitelisted_role_ids.default
            return true if guild_member.permission?(:administrator)
            return false if whitelisted_role_ids.empty?

            whitelisted_role_ids.any? { |role_id| guild_member.role?(role_id.to_i) }
          end.call
        end

        # Is the command allowed in this channel?
        # @note: Purposefully explicit
        def allowed?
          @allowed =
            if config_present?
              @config.allowed_in_text_channels?
            else
              @command.defines.allowed_in_text_channels.default
            end

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

        def to_h
          {
            config: @config&.attributes,
            enabled: self.enabled?,
            allowed: self.allowed?,
            whitelisted: self.whitelisted?,
            notify_when_disabled: self.notify_when_disabled?,
            cooldown_time: self.cooldown_time
          }
        end
      end
    end
  end
end
