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
              user: current_user,
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

        # Answers with the rows themselves rather than embeds, and with the lean query rather than the one Discord
        # uses. The website's only consumer is a picker that needs an ID, a name, a level and how full the garage is;
        # player_territories would ship every member and moderator of every territory to render a dropdown.
        def on_website_execute
          territories = query_exile_database!("reward_territories", uid: current_user.steam_uid)

          reply(
            territories.map do |territory|
              row = territory.to_h
              row.merge(garage_capacity: garage_capacity_for(row[:level]))
            end
          )
        end

        #
        # How many vehicles a territory's garage holds at the given level, or nil when that level has none.
        #
        # The sizes live on the connection rather than in the database, and the website has no connection of its own,
        # so the question is answered here while there is still something to ask.
        #
        # @param level [Integer] the territory's level
        #
        # @return [Integer, nil]
        #
        def garage_capacity_for(level)
          sizes = Array(target_server.connection&.metadata&.vg_max_sizes)
          return if sizes.empty?

          # Exile reads this list at (level - 1) max 0, and -1 is how it says a level has no garage at all
          capacity = sizes[(level.to_i - 1).clamp(0, sizes.size - 1)].to_i

          capacity if capacity >= 0
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
            raise_error!(:no_territories, user: current_user, server_id: target_server.server_id) if @response.blank?
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
