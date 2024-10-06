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
            player = ESM::Exile::Player.new(server: target_server, player_data: @response)
            reply(player.to_embed)
          end
        end

        private

        def check_for_no_target!
          raise_error!(:no_target, user: current_user.mention) if arguments.target.blank? && arguments.territory_id.blank?
        end

        def check_for_response!
          return if @response.present?

          raise_error!(:no_response, user: current_user.mention)
        end
      end
    end
  end
end
