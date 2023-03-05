# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Me < ESM::Command::Base
        set_type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def on_execute
          deliver!(query: "player_info", uid: current_user.esm_user.steam_uid)
        end

        def on_response(_, _)
          # TODO: V1 If the user isn't a member on the server, @response will be []
          player = ESM::Arma::Player.new(server: target_server, player: @response)
          reply(player.to_embed)
        end
      end
    end
  end
end
