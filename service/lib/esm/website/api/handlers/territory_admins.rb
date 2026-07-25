# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Warms and returns a community's territory-admin users as their ESM user ids.
        #
        # The website reads the shared cache directly on the hot path and only reaches here when that key is cold - a
        # server left up long enough that the entry expired without a reboot to refresh it. Recomputing repopulates the
        # shared cache for every later read, so this is the website's way to trigger the compute it can't run itself
        # (only the bot can resolve Discord role membership).
        #
        # @return [Array<Integer>, nil] the territory-admin user ids, or nil when the community can't be found
        #
        class TerritoryAdmins
          def self.call(community_id:, **)
            community = ESM::Community.find_by(id: community_id)
            return if community.nil?

            community.territory_admin_users.pluck(:id)
          end
        end
      end
    end
  end
end
