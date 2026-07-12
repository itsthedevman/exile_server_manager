# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Checks
        def check_failed!(error_name = nil, **args, &)
          raise_error!(error_name, **args.merge(path_prefix: "command_errors"), &)
        end

        def check_for_text_only!
          check_failed!(:text_only, user: current_user) if text_only? && !text_channel?
        end

        def check_for_dm_only!
          # DM commands are allowed in player mode
          return if current_community&.player_mode_enabled?

          check_failed!(:dm_only, user: current_user) if dm_only? && !dm_channel?
        end

        def check_for_owner!
          # Both sides must be a concrete id. `nil == nil` is true in Ruby and
          # would grant owner to anyone if owner_user_id is unset (unbackfilled
          # community) and the caller is somehow id-less (Ephemeral/unsaved).
          owner_id = target_community.owner_user_id
          caller_id = current_user&.id
          return if owner_id.present? && caller_id.present? && owner_id == caller_id

          check_failed!(:no_permissions, user: current_user)
        end

        def check_for_permissions!
          if !command_enabled?
            # If the community doesn't want to send a message, don't send a message.
            # This only applies to text channels. The user needs to know why the bot is not replying to their message
            if text_channel? && !notify_when_command_disabled?
              check_failed!(exception_class: ESM::Exception::CheckFailureNoMessage)
            else
              check_failed!(:command_not_enabled, user: current_user)
            end
          end

          if !command_allowed?
            check_failed!(:not_allowlisted, user: current_user)
          end

          if !command_allowed_in_channel?
            check_failed!(
              :not_allowed_in_text_channels,
              user: current_user,
              command_name: usage
            )
          end
        end

        def check_for_registered!
          return if !registration_required? || current_user.registered?

          check_failed!(:not_registered, user: current_user, full_username: current_user.distinct)
        end

        def check_for_cooldown!
          return unless on_cooldown?

          if current_cooldown.cooldown_type == "times"
            check_failed!(:on_cooldown_useage, user: current_user)

            return
          end

          check_failed!(
            :on_cooldown_time_left,
            user: current_user,
            time_left: current_cooldown.to_s
          )
        end

        def check_for_dev_only!
          # Empty on purpose
          raise ESM::Exception::CheckFailure, "" if dev_only? && !current_user.developer?
        end

        def check_for_connected_server!
          return unless argument?(:server_id)

          # Return if the server is not connected
          return if target_server.connected?

          check_failed!(:server_not_connected, user: current_user, server_id: arguments.server_id)
        end

        def check_for_nil_target_server!
          return unless argument?(:server_id)
          return if !target_server.nil?

          provided_server_id = arguments.server_id

          check_failed!(:invalid_server_id_blank, user: current_user) if provided_server_id.blank?

          # Attempt to correct them
          corrections = ESM::Server.correct_id(provided_server_id)

          if corrections.blank?
            check_failed!(:invalid_server_id, user: current_user, provided_server_id:)
          else
            corrections = corrections.join_map(", ") { |correction| "`#{correction}`" }

            check_failed!(:invalid_server_id_with_correction, user: current_user, provided_server_id:, correction: corrections)
          end
        end

        def check_for_nil_target_community!
          return unless argument?(:community_id)
          return if !target_community.nil?

          provided_community_id = arguments.community_id

          # Attempt to correct them
          corrections = ESM::Community.correct(provided_community_id)

          if corrections.blank?
            check_failed!(:invalid_community_id, user: current_user, provided_community_id:)
          else
            corrections = corrections.join_map(", ") { |correction| "`#{correction}`" }

            check_failed!(:invalid_community_id_with_correction, user: current_user, provided_community_id:, correction: corrections)
          end
        end

        def check_for_nil_target_user!
          return unless argument?(:target)
          return if !target_user.nil?

          check_failed!(:target_user_nil, user: current_user)
        end

        # Order matters!
        def check_for_player_mode!
          # This only affects text channels
          return unless text_channel?

          # This only affects player_mode
          return unless current_community.player_mode_enabled?

          # Allow commands with DM only
          return if dm_only?

          # Admin/Different - Disallow
          # Admin/Same - Allow
          # Player/Different - Allow
          # Player/Same - Allow
          # I don't use `unless` often, but in this case, it simplifies the logic.
          return unless type == :admin && target_community && (current_community.id != target_community.id)

          check_failed!(
            :player_mode_command_not_available,
            user: current_user,
            command_name: usage
          )
        end

        def check_for_different_community!
          # Only affects text channels
          return unless text_channel?

          # Only affects if player mode is disabled
          return if current_community.player_mode_enabled?

          # This doesn't affect commands with no target_community
          return if target_community.nil?

          # Allow if the command is being ran for the same community
          return if current_community.id == target_community.id

          # Allow if current_community is ESM, for debugging and support
          return if ESM.env.production? && current_community.esm_community?

          check_failed!(:different_community_in_text, user: current_user)
        end

        # Used by calling in a command that uses the request system.
        # This will raise ESM::Exception::CheckFailure if there is a pending request for the target_user
        def check_for_pending_request!
          return if request.nil?

          if target_user.nil? || current_user == target_user
            check_failed!(:pending_request_same_user, user: current_user)
          else
            check_failed!(:pending_request_different_user, user: current_user, target_user:)
          end
        end

        # Raises CheckFailure if the target_server does not belong to the current_community
        def check_for_owned_server!
          return if target_server.nil?
          return if target_server.community_id == current_community.id

          check_failed!(:owned_server, user: current_user, community_id: current_community.community_id)
        end

        # Checks if the target_user is registered
        # This will always raise if the target_user is an instance of User::Ephemeral. (They aren't registered)
        #
        # @raise ESM::Exception::CheckFailure
        def check_for_registered_target_user!
          return if target_user.nil? || target_user.registered?

          check_failed!(:target_not_registered, user: current_user, target_user:)
        end
      end
    end
  end
end
