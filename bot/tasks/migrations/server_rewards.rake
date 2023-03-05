# frozen_string_literal: true

namespace :migrations do
  namespace :server_rewards do
    task add_reward_id_and_cooldown_defaults: :environment do
      ESM::ServerReward.all.joins(:server).each do |reward|
        configuration = ESM::CommandConfiguration.select(:cooldown_quantity, :cooldown_type).where(community_id: reward.server.community_id, command_name: "reward").first

        reward.update(
          reward_id: nil,
          reward_vehicles: [],
          cooldown_quantity: configuration.cooldown_quantity,
          cooldown_type: configuration.cooldown_type
        )
      end
    end
  end
end
