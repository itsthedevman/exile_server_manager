# frozen_string_literal: true

FactoryBot.define do
  factory :server_reward, class: "ESM::ServerReward" do
    # attribute :server_id, :integer
    # attribute :reward_items, :json, default: nil
    # attribute :player_poptabs, :integer, default: 0
    # attribute :locker_poptabs, :integer, default: 0
    # attribute :respect, :integer, default: 0

    reward_items { { "Exile_Item_EMRE" => 2, "Chemlight_blue" => 5 } }
    player_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    locker_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    respect { Faker::Number.between(from: 1000, to: 20_000) }
  end
end
