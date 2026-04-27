# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    discord_id { Faker::Number.number(digits: 18).to_s }
    discord_username { Faker::Internet.username }
    steam_uid { "7656#{Faker::Number.number(digits: 13)}" }

    # Skip after_create callbacks that create associated records
    after(:build) do |user|
      user.class.skip_callback(:create, :after, :create_user_steam_data, raise: false)
      user.class.skip_callback(:create, :after, :create_id_defaults, raise: false)
    end

    after(:create) do |user|
      user.class.set_callback(:create, :after, :create_user_steam_data, raise: false)
      user.class.set_callback(:create, :after, :create_id_defaults, raise: false)
    end

    trait :unregistered do
      steam_uid { nil }
    end

    trait :with_defaults do
      after(:create) do |user|
        create(:user_default, user: user)
      end
    end
  end
end
