# frozen_string_literal: true

module ESM
  module Command
    module Server
      class ServerTerritories < ESM::Command::Base
        type :admin
        aliases :serverterritories, :allterritories, :all_territories
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :order_by, regex: /id|territory_name|owner_uid/, description: "commands.server_territories.arguments.order_by", default: :territory_name, type: :symbol

        def discord
          @checks.owned_server!
          deliver!(command_name: "allterritories", query: "list_territories_all")
        end

        def server
          # The data must an array if its not already.
          @response = [@response] if !@response.is_a?(Array)

          check_for_no_territories!

          tables = build_territory_tables
          tables.each { |table| reply("```\n#{table}\n```") }
        end

        def build_territory_tables
          tables = []

          # Sorted here on purpose. Makes it so I can test this functionality
          @response.sort_by!(&@arguments.order_by)

          # Two challenges for this code.
          # 1: The width of each row had to be less than 67 (10 characters per line reserved for spacing/separating)
          # 2: The overall size of the table (including spaces and separators) HAS to be under 1992 characters due to Discord's message limit
          @response.in_groups_of(20, false).each do |territories|
            table = Terminal::Table.new(headings: ["ID", "Name", "Owner UID"], style: { width: 67 })

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
          check_failed!(:no_server_territories, user: current_user.mention) if @response.blank?
        end
      end
    end
  end
end
