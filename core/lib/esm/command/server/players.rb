# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Players < ApplicationCommand
        # Unreleased until the new server dashboard is available
        unreleased!

        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #################################
        #
        # Website arguments (order does not matter)
        #

        argument :connected_since, :string,
          origins: [:website],
          required: true,
          modifier: ->(content) { content.presence && Time.parse(content).utc.strftime("%Y-%m-%d %H:%M:%S") }

        argument :limit, :integer, origins: [:website], required: true

        #################################
        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :list_players
        command_type :admin

        limit_to :text

        #################################

        def on_execute
          check_for_owned_server!

          connected_since = target_server.restart_interval.ago

          players = query_exile_database!("players_list", connected_since:, limit: 100)
            .select { |p| p[:online] }

          check_for_players!(players)

          tables = build_player_tables(players)
          tables.each { |table| reply("```\n#{table}\n```") }
        end

        def on_website_execute
          check_for_owned_server!

          results = query_exile_database!(
            "players_list",
            connected_since: arguments.connected_since,
            limit: arguments.limit
          )

          reply(results)
        end

        module V1
          def on_execute
            raise_server_version_not_supported!
          end
        end

        private

        def build_player_tables(players)
          # Two challenges for this code.
          # 1: The width of each row had to be less than 67 (10 characters per line reserved for spacing/separating)
          # 2: The overall size of the table (including spaces and separators) HAS to be under 1992 characters due to Discord's message limit
          players.in_groups_of(20, false).map do |player_slice|
            table = Terminal::Table.new(headings: ["Name", "UID"], style: {border: :unicode_round, width: 67})

            player_slice.each do |player|
              table << [
                player[:name],
                player[:uid]
              ]
            end

            table.to_s
          end
        end

        def check_for_players!(players)
          raise_error!(:no_players, user: current_user, server_id: target_server.server_id) if players.blank?
        end
      end
    end
  end
end
