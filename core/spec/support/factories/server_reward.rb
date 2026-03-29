# frozen_string_literal: true

FactoryBot.define do
  factory :server_reward, class: "ESM::ServerReward" do
    association :server

    reward_id { nil } # nil = default reward
    reward_items { {} }
    reward_vehicles { [] }
    player_poptabs { 0 }
    locker_poptabs { 0 }
    respect { 0 }
  end
end
