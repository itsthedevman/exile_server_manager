# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Removes a community: the bot leaves its Discord guild and the record is
        # destroyed. No-op when the requesting user lacks modify rights.
        #
        class CommunityDelete
          def self.call(id:, user_id:, **)
            info!(event: "community:delete", id: id, user_id: user_id)

            community = ESM::Community.where(id: id).first
            return if community.nil?

            user = ESM::User.where(id: user_id).first
            return if user.nil?

            discord_server = community.discord_server
            return if !community.modifiable_by?(user.discord_user.on(discord_server))

            discord_server.leave
            community.destroy
          end
        end
      end
    end
  end
end
