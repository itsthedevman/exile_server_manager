# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Reward < ESM::Command::Base
        set_type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 1

        argument :server_id

        def on_execute
          # Check for pending requests
          @checks.pending_request!

          # Check to see if the server has any rewards for the user before even sending the request
          check_for_reward_items!

          # Add the request
          add_request(
            to: current_user,
            description: I18n.t("commands.reward_v1.request_description", user: current_user.mention, server: target_server.server_id)
          )

          # Remind them to check their PMs
          embed = ESM::Embed.build(:success, description: I18n.t("commands.request.check_pm", user: current_user.mention))
          reply(embed)
        end

        def on_response(_, _)
          # Array<Array<item, quantity>>
          receipt = @response.receipt.to_h

          embed = ESM::Embed.build(
            :success,
            description: I18n.t(
              "commands.reward_v1.receipt",
              user: current_user.mention,
              items: receipt.format { |item, quantity| "- #{quantity}x #{item}\n" }
            )
          )

          reply(embed)
        end

        def request_accepted
          deliver!(command_name: "reward", function_name: "rewardPlayer", target_uid: current_user.steam_uid)
        end

        private

        def check_for_reward_items!
          reward = target_server.server_reward
          return if reward.reward_items.present? || reward.locker_poptabs.positive? || reward.player_poptabs.positive? || reward.respect.positive?

          check_failed!(:no_reward_items, user: current_user.mention)
        end
      end
    end
  end
end
