# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Checks
        def initialize(command)
          @command = command
        end

        def different_communities?
          @command.current_community&.id != @command.target_community&.id
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
          connected_server! if !@command.skipped_checks.include?(:connected_server)
        end

        def nil_targets!
          nil_target_server!
          nil_target_community!
          nil_target_user!
        end

        def text_only!
          raise ESM::Exception::CommandTextOnly, @command.current_user.mention if !@command.event.channel.text? && @command.text_only?
        end

        def dm_only!
          # DM commands are allowed in player mode
          return if @command.current_community&.player_mode_enabled?

          raise ESM::Exception::CommandDMOnly, @command.current_user.mention if !@command.event.channel.pm? && @command.dm_only?
        end

        def permissions!
          # Load the permissions AFTER we have checked for invalid communities.
          @command.permissions.load

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:command_not_enabled, prefix: @command.prefix, user: @command.current_user, command_name: @command.name) if !@command.permissions.enabled?
          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:not_whitelisted, prefix: @command.prefix, user: @command.current_user, command_name: @command.name) if !@command.permissions.whitelisted?
          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:not_allowed_in_text_channels, prefix: @command.prefix, user: @command.current_user, command_name: @command.name) if !@command.permissions.allowed?
        end

        def registered!
          return if !@command.registration_required? || @command.current_user.esm_user.registered?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:not_registered, user: @command.current_user)
        end

        def cooldown!
          return if ESM.env.test? && ESM::Test.skip_cooldown
          return if !@command.on_cooldown?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:on_cooldown, prefix: @command.prefix, user: @command.current_user, time_left: current_cooldown.to_s, command_name: @command.name)
        end

        def dev_only!
          # Empty on purpose
          raise ESM::Exception::CheckFailure, "" if @command.dev_only? && !@command.current_user.esm_user.developer?
        end

        def connected_server!
          return if @command.arguments.server_id.nil?
          return if ESM::Websocket.connected?(@command.arguments.server_id)

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:server_not_connected, user: @command.current_user, server_id: @command.arguments.server_id)
        end

        def nil_target_server!
          return if @command.arguments.server_id.nil?
          return if !@command.target_server.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:invalid_server_id, user: @command.current_user, provided_server_id: @command.arguments.server_id)
        end

        def nil_target_community!
          return if @command.arguments.community_id.nil?
          return if !@command.target_community.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:invalid_community_id, user: @command.current_user, provided_community_id: @command.arguments.community_id)
        end

        def nil_target_user!
          return if @command.arguments.target.nil?
          return if !@command.target_user.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:target_user_nil, user: @command.current_user)
        end

        # Order matters!
        def player_mode!
          # This only affects text channels
          return if !@command.event.channel.text?

          # This only affects player_mode
          return if !@command.current_community.player_mode_enabled?

          # Allow commands with DM only
          return if @command.dm_only?

          # Allow using commands on other communities
          return if @command.target_community && @command.current_community.id != @command.target_community.id

          # Only allow player commands
          return if @command.type == :player

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:player_mode_command_not_available, prefix: @command.prefix, user: @command.current_user, command_name: @command.name)
        end

        def different_community!
          # Only affects text channels
          return if !@command.event.channel.text?

          # Only affects if player mode is disabled
          return if @command.current_community.player_mode_enabled?

          # This doesn't affect commands with no @command.target_community
          return if @command.target_community.nil?

          # Allow if the command is being ran for the same community
          return if @command.current_community.id == @command.target_community.id

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:different_community_in_text, user: @command.current_user)
        end

        # Used by calling in a command that uses the request system.
        # This will raise ESM::Exception::CheckFailure if there is a pending request for the target_user
        def pending_request!
          return if request.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:pending_request, user: @command.current_user)
        end

        # Raises CheckFailure if the target_server does not belong to the current_community
        def owned_server!
          return if @command.target_server.nil?
          return if @command.target_server.community_id == @command.current_community.id

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:owned_server, user: @command.current_user, community_id: @command.current_community.community_id)
        end

        def registered_target_user!
          return if @command.target_user.nil? || @command.target_user.esm_user.registered?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:target_not_registered, user: @command.current_user, target_user: @command.target_user)
        end
      end
    end
  end
end
