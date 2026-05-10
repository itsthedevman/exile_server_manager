# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      discord_user { build(:discord_user) }
    end

    discord_id { discord_user.id.to_s }
    discord_username { discord_user.username }
    steam_uid { Faker::ESM.steam_uid }
    user_steam_data

    trait :unregistered do
      steam_uid { nil }
    end

    factory :developer do
      after(:build) do |user|
        next if ESM.config.dev_user_allowlist.include?(user.discord_id)

        ESM.config.dev_user_allowlist << user.discord_id
      end
    end
  end
end
