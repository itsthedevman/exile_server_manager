# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class SetId < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:territory_id]
        argument :old_territory_id, display_name: :from, template: :territory_id

        # See Argument::TEMPLATES[:territory_id]
        argument :new_territory_id, display_name: :to, template: :territory_id

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_type :player

        #################################

        def on_execute
          # Require at least 3 characters and a max of 20
          check_for_minimum_characters!
          check_for_maximum_characters!

          run_database_query(
            :set_id,
            steam_uid: current_user.steam_uid,
            territory_id: arguments.old_territory_id,
            new_territory_id: arguments.new_territory_id
          )

          reply(success_message)
        end

        module V1
          def on_execute
            # Require at least 3 characters and a max of 20
            check_for_minimum_characters!
            check_for_maximum_characters!

            # Set the request
            deliver!(
              command_name: "setterritoryid",
              query: "set_custom_territory_id",
              player_uid: current_user.steam_uid,
              old_territory_id: arguments.old_territory_id,
              new_territory_id: arguments.new_territory_id
            )
          end

          def on_response
            check_for_failure!
            reply(success_message)
          end

          def check_for_failure!
            return if @response.success

            # Don't set a cooldown if we errored.
            skip_action(:cooldown)

            # DLL Reason. This is a weird one since I can't localize the message
            if @response.reason
              raise_error! do
                ESM::Embed.build(:error, description: "I'm sorry #{current_user.mention}, #{@response.reason}")
              end
            end

            raise_error!(:access_denied, user: current_user.mention)
          end
        end

        private

        def check_for_minimum_characters!
          return if arguments.new_territory_id.nil?

          raise_error!(:minimum_characters, user: current_user.mention) if arguments.new_territory_id.size < 3
        end

        def check_for_maximum_characters!
          return if arguments.new_territory_id.nil?

          raise_error!(:maximum_characters, user: current_user.mention) if arguments.new_territory_id.size > 20
        end

        def success_message
          ESM::Embed.build(
            :success,
            description: I18n.t(
              "commands.set_id.success_message",
              server_id: target_server.server_id,
              old_territory_id: arguments.old_territory_id,
              new_territory_id: arguments.new_territory_id
            )
          )
        end
      end
    end
  end
end
