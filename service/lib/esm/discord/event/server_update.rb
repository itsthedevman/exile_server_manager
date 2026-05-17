# frozen_string_literal: true

module ESM
  module Discord
    module Event
      class ServerUpdate
        def initialize(server)
          @server = server
          @owner = server.owner

          @community = ESM::Community.from_discord(@server)
          @user = ESM::User.from_discord(@owner)
        end

        def run!
          update_community_owner
        end

        private

        def update_community_owner
          return if @community.owner_user_id == @user.id

          @community.update!(owner_user_id: @user.id)
        end
      end
    end
  end
end
