# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Pay < ESM::Command::Base
        type :player

        limit_to :dm
        requires :registration, :premium

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :territory_id

        def discord
          deliver!(function_name: "payTerritory", territory_id: @arguments.territory_id, uid: current_user.esm_user.steam_uid)
        end

        def server
          embed =
            ESM::Embed.build do |e|
              e.description = t(
                "commands.pay.embed.description",
                user: current_user.mention,
                server_id: target_server.server_id,
                territory_id: @arguments.territory_id,
                cost: @response.payment,
                locker_amount: @response.locker
              )

              e.color = :green
            end

          reply(embed)
        end
      end
    end
  end
end
