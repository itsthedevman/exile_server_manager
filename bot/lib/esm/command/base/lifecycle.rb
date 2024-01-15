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
            event = ESM::Event::ApplicationCommand.new(event)
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

          # Adding a comment to make this look better is always a weird idea
          info!(to_h)

          # Finish up the checks
          timers.time!(:before_execute) do
            check_for_nil_target_community! unless skipped_actions.nil_target_community?
            check_for_nil_target_server! unless skipped_actions.nil_target_server?
            check_for_nil_target_user! unless skipped_actions.nil_target_user?
            check_for_connected_server! unless skipped_actions.connected_server?
            check_for_cooldown! unless skipped_actions.cooldown?
            check_for_different_community! unless skipped_actions.different_community?
          end

          # Now execute the command
          result = nil
          timers.time!(:on_execute) do
            load_v1_code! if v1_code_needed? # V1

            result = on_execute
          end

          timers.time!(:after_execute) do
            # Update the cooldown after the command has ran just in case there are issues
            create_or_update_cooldown unless skipped_actions.cooldown?

            # This just tracks how many times a command is used
            ESM::CommandCount.increment_execution_counter(name)
          end

          result
        end

        # @param request [ESM::Request] The request to build this command with
        # @note Don't load `target_user` from the request. If the arguments contain a target, it will handle it
        def from_request(request)
          @request = request
          @current_channel = ESM.bot.channel(request.requested_from_channel_id)
          @current_user = request.requestor

          # Initialize our command from the request
          arguments.merge!(request.command_arguments.symbolize_keys) if request.command_arguments.present?

          timers.time!(:from_request) do
            load_v1_code! if v1_code_needed? # V1

            if @request.accepted
              request_accepted
            else
              # Reset the cooldown since the request was declined.
              current_cooldown.reset! if current_cooldown.present?

              request_declined
            end
          end
        end

        def on_execute
        end

        def on_response(_incoming_message, _outgoing_message)
        end

        def request_accepted
        end

        def request_declined
        end
      end
    end
  end
end
