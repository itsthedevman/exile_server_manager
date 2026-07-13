# frozen_string_literal: true

FactoryBot.define do
  factory :community, class: "ESM::Community" do
    sequence(:community_id) { |n| "test#{n}" }
    sequence(:guild_id) { |n| (900_000_000_000_000_000 + n).to_s }
    community_name { "Test Community" }
  end
end
