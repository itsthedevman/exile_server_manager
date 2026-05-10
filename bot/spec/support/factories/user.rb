# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      discord_user { build(:discord_user) }
    end

    discord_id { discord_user.id.to_s }
    discord_username { discord_user.username }
    steam_uid { Faker::Steam.uid }
    user_steam_data

    trait :unregistered do
      steam_uid { nil }
    end

    # Register the user as a member of `discord_server` after the AR record is built.
    # `discord_member_roles` is forwarded to the :discord_member factory so callers
    # can attach roles in one shot.
    trait :with_discord_member do
      transient do
        discord_server { nil }
        discord_member_roles { [] }
      end

      after(:build) do |user, evaluator|
        if evaluator.discord_server.nil?
          raise ArgumentError, "create(:user, :with_discord_member) requires `discord_server:`"
        end

        build(
          :discord_member,
          server: evaluator.discord_server,
          user: user.discord_user,
          roles: evaluator.discord_member_roles
        )
      end
    end

    factory :developer do
      after(:build) do |user|
        next if ESM.config.dev_user_allowlist.include?(user.discord_id)

        ESM.config.dev_user_allowlist << user.discord_id
      end
    end
  end
end
