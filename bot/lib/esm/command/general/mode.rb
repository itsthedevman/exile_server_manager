# frozen_string_literal: true

module ESM
  module Command
    module General
      class Mode < ESM::Command::Base
        type :admin
        limit_to :dm

        argument :community_id
        argument :mode, regex: /player|server/, description: I18n.t("commands.mode.arguments.mode")

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: false
        define :cooldown_time, modifiable: false, default: 2.seconds

        def discord
          check_for_permissions!
          check_for_same_mode!

          if @arguments.mode == "player"
            enable_player_mode
          else
            disable_player_mode
          end
        end

        module ErrorMessage
          def self.servers_exist(user:)
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.mode.error_messages.servers_exist.title", user: user.mention)
              e.description = I18n.t("commands.mode.error_messages.servers_exist.description")
              e.color = :red
            end
          end

          def self.same_mode(mode:)
            player_mode = mode == "player"

            ESM::Embed.build do |e|
              e.title = I18n.t("commands.mode.error_messages.same_mode.title")
              e.description = I18n.t("commands.mode.error_messages.same_mode.description", state: player_mode ? "enabled" : "disabled")
              e.color = :yellow
            end
          end

          def self.no_permissions(user:)
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.mode.error_messages.no_permissions.title", user: user.mention)
              e.description = I18n.t("commands.mode.error_messages.no_permissions.description")
              e.color = :red
            end
          end
        end

        #########################
        # Command Methods
        #########################

        def check_for_permissions!
          server = ESM.bot.servers[target_community.guild_id.to_i]
          guild_member = current_user.on(server)
          raise ESM::Exception::CheckFailure, error_message(:no_permissions, user: current_user) if guild_member.nil?

          return if guild_member.owner?

          raise ESM::Exception::CheckFailure, error_message(:no_permissions, user: current_user)
        end

        def check_for_same_mode!
          raise ESM::Exception::CheckFailure, error_message(:same_mode, mode: @arguments.mode) if same_mode?
        end

        def check_for_active_servers!
          raise ESM::Exception::CheckFailure, error_message(:servers_exist, user: current_user) if target_community.servers.any?
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
