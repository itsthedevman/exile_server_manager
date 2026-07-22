# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Lifecycle
        extend ActiveSupport::Concern

        class_methods do
          #
          # The entry point of a command
          # This is registered with Discordrb and is called as part of an interaction lifecycle
          #
          # @note This method will gracefully handle 99% of the errors automatically.
          # I recommend avoiding manually handling exceptions in a command's lifecycle so this system can handle it. But the choice is up to you
          #
          # @!visibility private
          #
          def event_hook(event)
            event = ESM::Discord::Event::ApplicationCommand.new(event)
            event.on_execution(self)
          end

          #
          # The website counterpart to #event_hook, for an invocation the page is not waiting on. Drives a persisted
          # ESM::ServiceCommand row through the command execution lifecycle and records the outcome on it.
          #
          # @!visibility private
          #
          def website_async_hook(event)
            event = ESM::Website::Event::AsyncCommand.new(event)
            event.on_execution(self)
          end

          #
          # The website counterpart to #event_hook, for an invocation the page is waiting on. Drives the same command
          # execution lifecycle but returns the command's reply rather than recording it.
          #
          # @!visibility private
          #
          def website_sync_hook(event)
            event = ESM::Website::Event::SyncCommand.new(event)
            event.on_execution(self)
          end
        end

        #
        # Called internally by #execute, this method handles when a command has been executed on Discord.
        #
        def from_discord!
          # Check for these BEFORE validating the arguments so even if an argument was invalid, it doesn't matter since these take priority
          timers.time!(:access_checks) do
            check_for_dev_only!
            check_for_registered!
            check_for_text_only!
            check_for_dm_only!
            check_for_player_mode!
            check_for_permissions!
          end

          # Now ensure the user hasn't smoked too much lead
          timers.time!(:argument_validation) do
            arguments.validate!
          end

          info!(to_h)

          timers.time!(:before_execute) do
            check_for_nil_target_community! unless skipped_actions.nil_target_community?
            check_for_nil_target_server! unless skipped_actions.nil_target_server?
            check_for_nil_target_user! unless skipped_actions.nil_target_user?
            check_for_connected_server! unless skipped_actions.connected_server?
            check_for_cooldown! unless skipped_actions.cooldown?
            check_for_different_community! unless skipped_actions.different_community?
          end

          timers.time!(:on_execute) do
            load_v1_code! if v1_code_needed? # V1
            on_execute
          end

          timers.time!(:after_execute) do
            # Update the cooldown after the command has ran just in case there are issues
            create_or_update_cooldown unless skipped_actions.cooldown?
          end

          nil
        end

        # @param request [ESM::Request] The request to build this command with
        # @note Don't load `target_user` from the request. If the arguments contain a target, it will handle it
        def from_request(request)
          @request = request

          arguments.merge!(request.command_arguments.symbolize_keys) if request.command_arguments.present?

          timers.time!(:from_request) do
            load_v1_code! if v1_code_needed? # V1

            if @request.accepted?
              on_request_accepted
            else
              # Reset the cooldown since the request was declined.
              current_cooldown.reset! if current_cooldown.present?

              on_request_declined
            end
          end
        end

        #
        # Called internally by #execute, this method handles when a command has been executed from the website.
        # Mirrors #from_discord! but runs only the access checks that apply off-Discord (registration and
        # permissions - no text/DM/player-mode gates) before validating arguments and dispatching to
        # #on_website_execute.
        #
        def from_website!
          # Check for these BEFORE validating the arguments so even if an argument was invalid it doesn't matter
          # since these take priority
          timers.time!(:access_checks) do
            check_for_registered!
            check_for_permissions!
          end

          # Now ensure the user hasn't smoked too much lead
          timers.time!(:argument_validation) do
            arguments.validate!
          end

          info!(to_h)

          timers.time!(:before_execute) do
            check_for_nil_target_community! unless skipped_actions.nil_target_community?
            check_for_nil_target_server! unless skipped_actions.nil_target_server?
            check_for_nil_target_user! unless skipped_actions.nil_target_user?
            check_for_connected_server! unless skipped_actions.connected_server?
            check_for_cooldown! unless skipped_actions.cooldown?
          end

          timers.time!(:on_execute) do
            on_website_execute
          end

          timers.time!(:after_execute) do
            # Update the cooldown after the command has ran just in case there are issues
            create_or_update_cooldown unless skipped_actions.cooldown?
          end

          nil
        end

        # TODO: Rename to #on_discord_execute
        def on_execute
        end

        def on_website_execute
        end

        def on_request_accepted
        end

        def on_request_declined
        end
      end
    end
  end
end
