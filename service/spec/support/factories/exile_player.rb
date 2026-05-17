# frozen_string_literal: true

FactoryBot.define do
  factory :exile_player, class: "ESM::ExilePlayer" do
    name { Faker::Name.name }
  end
end
