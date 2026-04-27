# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Territories < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :for

        #
        # Configuration
        #

        change_attribute :allowed_in_text_channels, default: false

        command_namespace :server, :my, command_name: :territories
        command_type :player

        #################################

        def on_execute
          territories = query_exile_database!("player_territories", uid: current_user.steam_uid)

          if territories.size == 0
            raise_error!(
              :no_territories,
              user: current_user.mention,
              server_id: target_server.server_id
            )
          end

          territories.each do |territory|
            embed = ESM::Exile::Territory.new(
              server: target_server,
              territory: territory.to_h
            ).to_embed

            reply(embed)
          end
        end

        ########################################################################

        module V1
          def on_execute
            deliver!(query: "list_territories", uid: current_user.steam_uid)
          end

          def on_response
            check_for_no_territories!

            # Apparently past me I didn't default the response to an array if there was only one territory...
            @response = [@response] if @response.is_a?(OpenStruct)

            @response.each do |territory|
              reply(territory_embed(territory))
            end
          end

          private

          def check_for_no_territories!
            raise_error!(:no_territories, user: current_user.mention, server_id: target_server.server_id) if @response.blank?
          end

          def territory_embed(territory)
            @territory = ESM::Exile::Territory.new(server: target_server, territory: territory)
            @territory.to_embed
          end
        end
      end
    end
  end
end
