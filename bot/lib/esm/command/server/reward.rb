# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        change_attribute :cooldown_time, default: 1.second

        command_type :player

        #################################

        def on_execute
          # Check for pending requests
          check_for_pending_request!

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

          raise_error!(:no_reward_items, user: current_user.mention)
        end
      end
    end
  end
end
