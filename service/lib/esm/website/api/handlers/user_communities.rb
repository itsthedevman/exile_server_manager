# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns the IDs of communities the user belongs to among the given guilds,
        # optionally filtered to those they can modify.
        #
        class UserCommunities
          def self.call(id:, guild_ids:, check_for_perms: false, **)
            user = ESM::User.find_by(id: id)
            return if user.nil?

            communities = ESM::Community.select(
              :id, :guild_id, :dashboard_access_role_ids,
              :community_name, :player_mode_enabled, :icon_url
            ).where(guild_id: guild_ids)

            return [] if communities.blank?

            discord_user = user.discord_user

            communities.filter_map do |community|
              server = community.discord_server
              next if server.nil?

              community.update(community_name: server.name, icon_url: server.icon_url)

              discord_member = discord_user.on(server)
              next if discord_member.nil?
              next if check_for_perms && !community.modifiable_by?(discord_member)

              community.id
            rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
              # Bot can't see this specific guild or the user's membership.
              # Skip and keep the rest of the user's communities.
              nil
            end
          end
        end
      end
    end
  end
end
