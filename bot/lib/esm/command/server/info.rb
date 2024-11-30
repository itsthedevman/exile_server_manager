# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Info < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # See Argument::TEMPLATES[:target]
        # Optional: This command works for players or territories
        argument :target, display_name: :whom, required: false

        # See Argument::TEMPLATES[:territory_id]
        # Optional: This command works for players or territories
        argument :territory_id, display_name: :territory, required: false

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :find
        command_type :admin

        limit_to :text

        skip_action :nil_target_user

        #################################

        def on_execute
          # Ensure we were given a target or territory ID
          check_for_no_target!

          # Territory ID takes priority since both arguments are optional
          # and both can be provided
          #
          # Reasoning:
          #   Given the weird scenario, user gives a mention plus a territory ID thinking
          #   that it will do some filter...
          embed =
            if arguments.territory_id.present?
              query_for_territory_info!
            else
              query_for_player_info!
            end

          reply(embed)
        end

        private

        def query_for_territory_info!
          territory = query_exile_database!(
            "territory_info",
            territory_id: arguments.territory_id
          ).first

          check_for_territory_info!(territory)

          # This takes a hash
          territory = ESM::Exile::Territory.new(server: target_server, territory:)
          territory.to_embed
        end

        def query_for_player_info!
          player = query_exile_database!(
            "player_info",
            uid: target_user.steam_uid
          ).first

          check_for_player_info!(player)

          # This takes an object
          # Territory and Player need to be updated to match
          player = ESM::Exile::Player.new(server: target_server, player: player.to_istruct)
          player.to_embed
        end

        def check_for_no_target!
          return unless arguments.target.blank? && arguments.territory_id.blank?

          raise_error!(:no_target, user: current_user.mention)
        end

        def check_for_player_info!(result)
          return if result.present?

          raise_error!(
            :no_player_info,
            user: current_user.mention,
            target: arguments.target
          )
        end

        def check_for_territory_info!(result)
          return if result.present?

          raise_error!(
            :no_territory_info,
            user: current_user.mention,
            territory_id: arguments.territory_id
          )
        end

        module V1
          def on_execute
            # Ensure we were given a target or territory ID
            check_for_no_target!

            # Territory ID takes priority since both arguments are optional, and both can be provided
            # Reasoning: Given the weird scenario, user gives a mention plus a territory ID thinking that it will do some filter...
            if arguments.territory_id.present?
              deliver!(query: "territory_info", territory_id: arguments.territory_id)
            else
              deliver!(query: "player_info", uid: target_user.steam_uid)
            end
          end

          def on_response
            # I'm not quite sure if this is needed, but just in case...
            check_for_response!

            # The fact that it has an ID indicates it was a territory...
            if @response.id
              territory = ESM::Exile::Territory.new(server: target_server, territory: @response)
              reply(territory.to_embed)
            else
              player = ESM::Exile::Player.new(server: target_server, player: @response)
              reply(player.to_embed)
            end
          end

          private

          def check_for_response!
            return if @response.present?

            raise_error!(:no_response, user: current_user.mention)
          end
        end
      end
    end
  end
end
