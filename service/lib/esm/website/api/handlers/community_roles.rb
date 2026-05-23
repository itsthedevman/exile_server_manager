# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns the community's selectable roles for the website (excludes admin
        # roles and @everyone), sorted top-to-bottom as they appear in Discord.
        #
        class CommunityRoles
          def self.call(id:, **)
            info!(event: "community:roles", id: id)

            community = ESM::Community.find_by(id: id)
            return if community.nil?

            server_roles = community.discord_server&.roles
            return if server_roles.blank?

            server_roles.sort_by(&:position).reverse.filter_map do |role|
              next if role.permissions.administrator || role.name == "@everyone"

              {
                id: role.id.to_s,
                name: role.name,
                color: role.color.hex,
                disabled: false
              }
            end
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot can't fetch the guild's roles. Caller sees empty list.
            nil
          end
        end
      end
    end
  end
end
