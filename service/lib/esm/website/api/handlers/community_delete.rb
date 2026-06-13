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
            community = ESM::Community.find_by(id:)
            return if community.nil?

            user = ESM::User.find_by(id: user_id)
            return if user.nil?

            discord_server = community.discord_server
            return if discord_server.nil?
            return if !community.modifiable_by?(user.discord_user.on(discord_server))

            discord_server.leave
            community.destroy
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot can't reach the guild to verify or leave. Refuse the destroy
            # so we don't tear down DB state without confirming Discord side.
            nil
          end
        end
      end
    end
  end
end
