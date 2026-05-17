# frozen_string_literal: true

FactoryBot.define do
  factory :log, class: "ESM::Log" do
    association :server, factory: :server

    search_text { "Search Text" }
    expires_at { Faker::Time.forward }
  end
end
