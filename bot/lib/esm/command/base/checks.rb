# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Checks
        def initialize(command, skipped_checks)
          @command = command
          @skipped_checks = skipped_checks
        end

        def different_communities?
          current_community&.id != @command.target_community&.id
        end

        # Order matters!
        def run_all!
          dev_only!
          registered!
          player_mode!
          text_only!
          dm_only!

          nil_targets!
          different_community!
          permissions!
          cooldown!

          # Check for skip outside of the method so it can be called later if need be
          connected_server! if !@skipped_checks.include?(:connected_server)
        end

        def nil_targets!
          nil_target_server!
          nil_target_community!
          nil_target_user!
        end

        def check_failed!(name = nil, **args, &block)
          @command.check_failed!(name, args, &block)
        end

        def current_user
          @command.current_user
        end

        def current_community
          @command.current_community
        end

        def target_user
          @command.target_user
        end

        def target_server
          @command.target_server
        end

        def text_only!
          check_failed!(:text_only, user: current_user.mention) if !@command.event.channel.text? && @command.text_only?
        end

        def dm_only!
          # DM commands are allowed in player mode
          return if current_community&.player_mode_enabled?

          check_failed!(:dm_only, user: current_user.mention) if !@command.event.channel.pm? && @command.dm_only?
        end

        def permissions!
          # Load the permissions AFTER we have checked for invalid communities.
          @command.permissions.load

          if !@command.permissions.enabled?
            check_failed!(
              :command_not_enabled,
              prefix: @command.prefix,
              user: current_user,
              command_name: @command.name
            )
          end

          if !@command.permissions.whitelisted?
            check_failed!(
              :not_whitelisted,
              prefix: @command.prefix,
              user: current_user,
              command_name: @command.name
            )
          end

          if !@command.permissions.allowed?
            check_failed!(
              :not_allowed_in_text_channels,
              prefix: @command.prefix,
              user: current_user,
              command_name: @command.name
            )
          end
        end

        def registered!
          return if !@command.registration_required? || current_user.esm_user.registered?

          check_failed!(:not_registered, user: current_user)
        end

        def cooldown!
          return if ESM.env.test? && ESM::Test.skip_cooldown
          return if !@command.on_cooldown?

          check_failed!(
            :on_cooldown,
            prefix: @command.prefix,
            user: current_user,
            time_left: current_cooldown.to_s,
            command_name: @command.name
          )
        end

        def dev_only!
          # Empty on purpose
          raise ESM::Exception::CheckFailure, "" if @command.dev_only? && !current_user.esm_user.developer?
        end

        def connected_server!
          return if @command.arguments.server_id.nil?
          return if ESM::Websocket.connected?(@command.arguments.server_id)

          check_failed!(:server_not_connected, user: current_user.mention, server_id: @command.arguments.server_id)
        end

        def nil_target_server!
          return if @command.arguments.server_id.nil?
          return if !target_server.nil?

          check_failed! do
            provided_server_id = @command.arguments.server_id

            # Attempt to correct them
            corrections = ESM::Websocket.correct(provided_server_id)

            ESM::Embed.build do |e|
              e.description =
                if corrections.blank?
                  I18n.t(
                    "command_errors.invalid_server_id",
                    user: current_user.mention,
                    provided_server_id: provided_server_id
                  )
                else
                  corrections = corrections.format(join_with: ", ") { |correction| "`#{correction}`" }

                  I18n.t(
                    "command_errors.invalid_server_id_with_correction",
                    user: current_user.mention,
                    provided_server_id: provided_server_id,
                    correction: corrections
                  )
                end

              e.color = :red
            end
          end
        end

        def nil_target_community!
          return if @command.arguments.community_id.nil?
          return if !@command.target_community.nil?

          check_failed! do
            provided_community_id = @command.arguments.community_id

            # Attempt to correct them
            corrections = ESM::Community.correct(provided_community_id)

            ESM::Embed.build do |e|
              e.description =
                if corrections.blank?
                  I18n.t(
                    "command_errors.invalid_community_id",
                    user: current_user.mention,
                    provided_community_id: provided_community_id
                  )
                else
                  corrections = corrections.format(join_with: ", ") { |correction| "`#{correction}`" }

                  I18n.t(
                    "command_errors.invalid_community_id_with_correction",
                    user: current_user.mention,
                    provided_community_id: provided_community_id,
                    correction: corrections
                  )
                end

              e.color = :red
            end
          end
        end

        def nil_target_user!
          return if @command.arguments.target.nil?
          return if !target_user.nil?

          check_failed!(:target_user_nil, user: current_user)
        end

        # Order matters!
        def player_mode!
          # This only affects text channels
          return if !@command.event.channel.text?

          # This only affects player_mode
          return if !current_community.player_mode_enabled?

          # Allow commands with DM only
          return if @command.dm_only?

          # Allow using commands on other communities
          return if @command.target_community && current_community.id != @command.target_community.id

          # Only allow player commands
          return if @command.type == :player

          check_failed!(:player_mode_command_not_available, prefix: @command.prefix, user: current_user.mention, command_name: @command.name)
        end

        def different_community!
          # Only affects text channels
          return if !@command.event.channel.text?

          # Only affects if player mode is disabled
          return if current_community.player_mode_enabled?

          # This doesn't affect commands with no @command.target_community
          return if @command.target_community.nil?

          # Allow if the command is being ran for the same community
          return if current_community.id == @command.target_community.id

          check_failed!(:different_community_in_text, user: current_user)
        end

        # Used by calling in a command that uses the request system.
        # This will raise ESM::Exception::CheckFailure if there is a pending request for the target_user
        def pending_request!
          return if @command.request.nil?

          check_failed!(:pending_request, user: current_user)
        end

        # Raises CheckFailure if the target_server does not belong to the current_community
        def owned_server!
          return if target_server.nil?
          return if target_server.community_id == current_community.id

          check_failed!(:owned_server, user: current_user, community_id: current_community.community_id)
        end

        def registered_target_user!
          return if target_user.nil? || target_user.esm_user.registered?

          check_failed!(:target_not_registered, user: current_user, target_user: target_user)
        end
      end
    end
  end
end
