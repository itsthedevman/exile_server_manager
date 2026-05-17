# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class ServerTerritories < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # Optional: Has a default value
        argument :order_by,
          default: "territory_name",
          choices: {
            id: "ID",
            territory_name: "Territory name",
            owner_uid: "Owner UID"
          },
          checked_against_if: true,
          checked_against: ["id", "territory_name", "owner_uid"]

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :territory, :admin, command_name: :list
        command_type :admin

        limit_to :text

        #################################

        def on_execute
          check_for_owned_server!

          @territories = query_exile_database!("all_territories").map(&:to_istruct)
          check_for_no_territories!

          tables = build_territory_tables
          tables.each { |table| reply("```\n#{table}\n```") }
        end

        module V1
          def on_execute
            check_for_owned_server!
            deliver!(command_name: "allterritories", query: "list_territories_all")
          end

          def on_response
            # The data must an array if its not already.
            @territories =
              if @response.is_a?(Array)
                @response
              else
                [@response]
              end

            check_for_no_territories!

            tables = build_territory_tables
            tables.each { |table| reply("```\n#{table}\n```") }
          end
        end

        private

        def build_territory_tables
          tables = []

          # Sorted here on purpose. Makes it so I can test this functionality
          @territories.sort_by!(&arguments.order_by.to_sym)

          # Two challenges for this code.
          # 1: The width of each row had to be less than 67 (10 characters per line reserved for spacing/separating)
          # 2: The overall size of the table (including spaces and separators) HAS to be under 1992 characters due to Discord's message limit
          @territories.in_groups_of(20, false).each do |territories|
            table = Terminal::Table.new(headings: ["ID", "Name", "Owner UID"], style: {border: :unicode_round, width: 67})

            territories.each do |territory|
              table << [
                territory.id.truncate(20),
                territory.territory_name.truncate(20),
                territory.owner_uid
              ]
            end

            # Add the table to all the tables
            tables << table.to_s
          end

          # Return the tables
          tables
        end

        def check_for_no_territories!
          raise_error!(:no_server_territories, user: current_user.mention, server_id: target_server.server_id) if @territories.blank?
        end
      end
    end
  end
end
