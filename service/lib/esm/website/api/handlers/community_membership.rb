# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns a user's Discord membership within a community: the ids of the roles they hold and whether they hold
        # Discord's administrator permission.
        #
        # @return [Hash, nil] {role_ids: [String], administrator: Boolean}, or nil when the guild or the user's
        #   membership in it can't be seen.
        #
        class CommunityMembership
          def self.call(user_id:, community_id:)
            user = ESM::User.find_by(id: user_id)
            community = ESM::Community.find_by(id: community_id)
            return if user.nil? || community.nil?

            discord_server = community.discord_server
            return if discord_server.nil?

            member = user.discord_user&.on(discord_server)
            return if member.nil?

            {
              # @everyone is dropped: every member holds it and the allowlist picker never lists it, so it's never a
              # role a command's allowlist is keyed to.
              role_ids: member.roles.filter_map { |role| role.id.to_s unless role.name == "@everyone" },
              administrator: member.permission?(:administrator)
            }
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot can't see this guild or the user's membership in it. Caller treats an absent membership as no roles.
            nil
          end
        end
      end
    end
  end
end
