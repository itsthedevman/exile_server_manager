# frozen_string_literal: true

FactoryBot.define do
  factory :server_reward, class: "ESM::ServerReward" do
    reward_vehicles do
      reward_vehicles = []

      vehicles = ESM::Arma::ClassLookup.where(category: ESM::Arma::ClassLookup::CATEGORY_VEHICLES)
      Faker::Number.between(from: 1, to: 5).times do
        reward_vehicles << {class_name: vehicles.keys.sample, spawn_location: ["nearby", "virtual_garage", "player_decides"].sample}
      end

      reward_vehicles
    end

    reward_items do
      reward_items = {}

      items = ESM::Arma::ClassLookup.where(category: ESM::Arma::ClassLookup::CATEGORY_EXILE)
      Faker::Number.between(from: 2, to: 10).times do
        reward_items[items.keys.sample] = Faker::Number.between(from: 1, to: 5)
      end

      reward_items
    end

    player_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    locker_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    respect { Faker::Number.between(from: 1000, to: 20_000) }
  end
end
