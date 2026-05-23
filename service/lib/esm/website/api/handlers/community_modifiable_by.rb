# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns whether the user has modify rights on the community (admin role,
        # owner, or membership in a configured admin role).
        #
        class CommunityModifiableBy
          def self.call(id:, user_id:, **)
            info!(event: "community:modifiable_by?", id: id, user_id: user_id)

            community = ESM::Community.find_by(id: id)
            return if community.nil? || community.discord_server.nil?

            user = ESM::User.find_by(id: user_id)
            return if user.nil?

            community.modifiable_by?(user.discord_user.on(community.discord_server))
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot can't see the guild or the user's membership in it. Anyone
            # the bot can't verify is treated as not allowed to modify.
            false
          end
        end
      end
    end
  end
end
