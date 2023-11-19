# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Me < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_namespace :server, :my, command_name: :player
        command_type :player

        #################################

        def on_execute
          if v2_target_server?
            query_arma("me", uid: current_user.steam_uid)
          else
            deliver!(query: "player_info", uid: current_user.steam_uid)
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
