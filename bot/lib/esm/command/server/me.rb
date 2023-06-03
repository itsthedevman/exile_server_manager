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
          if v2_target_server?
            query_arma("me", uid: current_user.steam_uid)
          else
            deliver!(query: "player_info", uid: current_user.esm_user.steam_uid)
          end
        end

        def on_response(incoming_message, _outgoing_message)
          player_data =
            if v2_target_server?
              incoming_message.data.results.first&.to_struct
            else
              # V1
              # @response will be an empty array if the user has not joined the server
              # Converting to nil for compatibility
              @response.presence
            end

          if player_data.nil?
            embed = ESM::Embed.build(
              :error,
              description: I18n.t(
                "exceptions.extension.account_does_not_exist",
                user: current_user.mention,
                server_id: target_server.server_id
              )
            )

            reply(embed)
            return
          end

          player = ESM::Exile::Player.new(server: target_server, player_data: player_data)
          reply(player.to_embed)
        end
      end
    end
  end
end
