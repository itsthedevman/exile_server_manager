# frozen_string_literal: true

FactoryBot.define do
  factory :log, class: "ESM::Log" do
    association :server
    association :user

    search_text { Faker::Lorem.sentence }

    after(:build) do |log|
      log.requestors_user_id = log.user.discord_id if log.user
    end
  end
end
