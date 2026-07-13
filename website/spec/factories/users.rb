# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    sequence(:discord_id) { |n| (800_000_000_000_000_000 + n).to_s }
    sequence(:discord_username) { |n| "tester#{n}" }
    sequence(:steam_uid) { |n| (76_561_198_000_000_000 + n).to_s }
  end
end
