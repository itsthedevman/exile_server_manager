# frozen_string_literal: true

module ESM
  module Command
    module General
      class Mode < ESM::Command::Base
        type :admin
        limit_to :dm

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: false
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :community_id
        argument :mode, regex: /player|server/, description: "commands.mode.arguments.mode"

        def discord
          check_for_owner!
          check_for_same_mode!

          if @arguments.mode == "player"
            enable_player_mode
          else
            disable_player_mode
          end
        end

        #########################
        # Command Methods
        #########################

        def check_for_owner!
          server = ESM.bot.servers[target_community.guild_id.to_i]
          guild_member = current_user.on(server)
          check_failed!(:no_permissions, user: current_user.mention) if guild_member.nil?

          return if guild_member.owner?

          check_failed!(:no_permissions, user: current_user.mention)
        end

        def check_for_same_mode!
          check_failed!(:same_mode, state: @arguments.mode == "player" ? "enabled" : "disabled") if same_mode?
        end

        def check_for_active_servers!
          check_failed!(:servers_exist, user: current_user.mention) if target_community.servers.any?
        end

        def same_mode?
          (@arguments.mode == "player" && target_community.player_mode_enabled?) ||
            (@arguments.mode == "server" && !target_community.player_mode_enabled?)
        end

        def enable_player_mode
          check_for_active_servers!

          # Enable Player Mode
          target_community.update!(player_mode_enabled: true)

          # Reply back
          ESM::Embed.build do |e|
            e.description = I18n.t("commands.mode.enabled", community_name: target_community.name)
            e.color = :green
          end
        end

        def disable_player_mode
          # Disable player mode
          target_community.update!(player_mode_enabled: false)

          # Reply back
          ESM::Embed.build do |e|
            e.description = I18n.t("commands.mode.disabled", community_name: target_community.name)
            e.color = :green
          end
        end
      end
    end
  end
end
