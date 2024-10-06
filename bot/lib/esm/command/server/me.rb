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
          response = query_exile_database!("me", uid: current_user.steam_uid)
          player_data = response.first&.to_struct

          reply(build_embed(player_data))
        end

        module V1
          def on_execute
            deliver!(query: "player_info", uid: current_user.steam_uid)
          end

          def on_response
            # V1
            # @response will be an empty array if the user has not joined the server
            # Converting to nil for compatibility
            player_data = @response.presence

            reply(build_embed(player_data))
          end
        end

        private

        def build_embed(player_data)
          if player_data
            player = ESM::Exile::Player.new(server: target_server, player_data: player_data)
            return player.to_embed
          end

          ESM::Embed.build(
            :error,
            description: I18n.t(
              "exceptions.extension.account_does_not_exist",
              user: current_user.mention,
              server_id: target_server.server_id
            )
          )
        end
      end
    end
  end
end
