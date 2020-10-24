# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Info < ESM::Command::Base
        type :admin
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :target, default: nil
        argument :territory_id, default: nil

        def discord
          # Ensure we were given a target or territory ID
          check_for_no_target!

          # Territory ID takes priority since both arguments are optional, and both can be provided
          # Reasoning: Given the weird scenario, user gives a mention plus a territory ID thinking that it will do some filter...
          if @arguments.territory_id.present?
            deliver!(query: "territory_info", territory_id: @arguments.territory_id)
          else
            deliver!(query: "player_info", uid: target_user.steam_uid)
          end
        end

        def server
          # I'm not quite sure if this is needed, but just in case...
          check_for_response!

          # The fact that it has an ID indicates it was a territory...
          if @response.id
            territory = ESM::Arma::Territory.new(server: target_server, territory: @response)
            reply(territory.to_embed)
          else
            player = ESM::Arma::Player.new(server: target_server, player: @response)
            reply(player.to_embed)
          end
        end

        private

        def check_for_no_target!
          check_failed!(:no_target, user: current_user.mention) if @arguments.target.nil? && @arguments.territory_id.nil?
        end

        def check_for_response!
          return if @response.present?

          check_failed!(:no_response, user: current_user.mention)
        end
      end
    end
  end
end
