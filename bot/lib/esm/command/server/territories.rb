# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Territories < ESM::Command::Base
        type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: false
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def discord
          deliver!(query: "list_territories", uid: current_user.esm_user.steam_uid)
        end

        def server
          check_for_no_territories!

          # Apparently past me I didn't default the response to an array if there was only one territory...
          @response = [@response] if @response.is_a?(OpenStruct)

          @response.each do |territory|
            reply(territory_embed(territory))
          end
        end

        #########################
        # Command Methods
        #########################
        def check_for_no_territories!
          check_failed!(:no_territories, user: current_user.mention, server_id: target_server.server_id) if @response.blank?
        end

        def territory_embed(territory)
          @territory = ESM::Arma::Territory.new(server: target_server, territory: territory)
          @territory.to_embed
        end
      end
    end
  end
end
