# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns the community's Discord users as serialized hashes for the
        # website's user-picker.
        #
        class CommunityUsers
          def self.call(id:, **)
            info!(event: "community:users", id: id)

            community = ESM::Community.find_by(id: id)
            return if community.nil?

            users = community.discord_server.users
            return if users.blank?

            users.map(&:to_h)
          end
        end
      end
    end
  end
end
