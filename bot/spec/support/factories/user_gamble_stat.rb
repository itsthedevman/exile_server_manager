# frozen_string_literal: true

FactoryBot.define do
  factory :user_gamble_stat, class: "ESM::UserGambleStat" do
    association :server, factory: :server
    association :user
  end
end
