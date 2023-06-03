# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Metadata
        def usage
          @usage ||= "#{distinct} #{@arguments.map(&:to_s).join(" ")}"
        end

        # Don't memoize this, prefix can change based on when its called
        def distinct
          "#{prefix}#{name}"
        end

        def offset
          distinct.size
        end

        def example
          I18n.t("commands.#{@name}.example", prefix: prefix, default: "")
        end

        def description
          I18n.t("commands.#{@name}.description", prefix: prefix, default: "")
        end

        def prefix
          return ESM.config.prefix if current_community&.command_prefix.nil?

          current_community.command_prefix
        end

        def to_h
          {
            name: name,
            current_community: current_community&.attributes,
            current_channel: current_channel.inspect,
            current_user: current_user.inspect,
            current_cooldown: current_cooldown&.attributes,
            target_community: target_community&.attributes,
            target_server: target_server&.attributes,
            target_user: target_user.respond_to?(:attributes) ? target_user.attributes : target_user.inspect,
            target_uid: target_uid,
            same_user: same_user?,
            dm_only: dm_only?,
            text_only: text_only?,
            dev_only: dev_only?,
            registration_required: registration_required?,
            whitelist_enabled: whitelist_enabled?,
            on_cooldown: on_cooldown?,
            permissions: @permissions.to_h
          }
        end
      end
    end
  end
end
