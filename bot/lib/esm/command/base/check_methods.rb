# frozen_string_literal: true

module ESM
  module Command
    class Base
      module CheckMethods
        def different_communities?
          current_community&.id != target_community&.id
        end

        # Order matters!
        def check_for_all_of_the_checks!
          check_for_dev_only!
          check_for_registered!
          check_for_player_mode!
          check_for_text_only!
          check_for_dm_only!

          check_for_nil_targets!
          check_for_different_community!
          check_for_permissions!
          check_for_cooldown!

          # Check for skip outside of the method so it can be called later if need be
          check_for_connected_server! if !@skipped_checks.include?(:connected_server)
        end

        def check_for_text_only!
          raise ESM::Exception::CommandTextOnly, current_user.mention if !@event.channel.text? && text_only?
        end

        def check_for_dm_only!
          # DM commands are allowed in player mode
          return if current_community&.player_mode_enabled?

          raise ESM::Exception::CommandDMOnly, current_user.mention if !@event.channel.pm? && dm_only?
        end

        def check_for_permissions!
          # Load the permissions AFTER we have checked for invalid communities.
          load_permissions

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:command_not_enabled, user: current_user, command_name: self.name) if !enabled?
          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:not_whitelisted, user: current_user, command_name: self.name) if !whitelisted?
          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:not_allowed_in_text_channels, user: current_user, command_name: self.name) if !allowed?
        end

        def check_for_registered!
          return if !registration_required? || current_user.esm_user.registered?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:not_registered, user: current_user)
        end

        def check_for_cooldown!
          return if ESM.env.test? && ESM::Test.skip_cooldown
          return if !on_cooldown?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:on_cooldown, user: current_user, time_left: current_cooldown.to_s, command_name: @name)
        end

        def check_for_dev_only!
          # Empty on purpose
          raise ESM::Exception::CheckFailure, "" if dev_only? && !current_user.esm_user.developer?
        end

        def check_for_connected_server!
          return if @arguments.server_id.nil?
          return if ESM::Websocket.connected?(@arguments.server_id)

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:server_not_connected, user: current_user, server_id: @arguments.server_id)
        end

        def check_for_nil_targets!
          check_for_nil_target_server!
          check_for_nil_target_community!
          check_for_nil_target_user!
        end

        def check_for_nil_target_server!
          return if @arguments.server_id.nil?
          return if !target_server.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:invalid_server_id, user: current_user, provided_server_id: @arguments.server_id)
        end

        def check_for_nil_target_community!
          return if @arguments.community_id.nil?
          return if !target_community.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:invalid_community_id, user: current_user, provided_community_id: @arguments.community_id)
        end

        def check_for_nil_target_user!
          return if @arguments.target.nil?
          return if !target_user.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:target_user_nil, user: current_user)
        end

        # Order matters!
        def check_for_player_mode!
          # This only affects text channels
          return if !@event.channel.text?

          # This only affects player_mode
          return if !current_community.player_mode_enabled?

          # Allow commands with DM only
          return if dm_only?

          # Allow using commands on other communities
          return if target_community && current_community.id != target_community.id

          # Only allow player commands
          return if @type == :player

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:player_mode_command_not_available, user: current_user, command_name: @name)
        end

        def check_for_different_community!
          # Only affects text channels
          return if !@event.channel.text?

          # Only affects if player mode is disabled
          return if current_community.player_mode_enabled?

          # This doesn't affect commands with no target_community
          return if target_community.nil?

          # Allow if the command is being ran for the same community
          return if current_community.id == target_community.id

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:different_community_in_text, user: current_user)
        end

        # Used by calling in a command that uses the request system.
        # This will raise ESM::Exception::CheckFailure if there is a pending request for the target_user
        def check_for_pending_request!
          return if request.nil?

          raise ESM::Exception::CheckFailure, ESM::Command::Base.error_message(:pending_request, user: current_user)
        end
      end
    end
  end
end
