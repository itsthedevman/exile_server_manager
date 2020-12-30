# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      not_user {}
      users { YAML.load_file("#{File.expand_path("./spec/support/config")}/test_users.yml").map(&:deep_symbolize_keys) }
      user { users.sample }
    end

    # attribute :discord_id, :string
    # attribute :discord_username, :string
    # attribute :discord_discriminator, :string
    # attribute :discord_avatar, :text, default: nil
    # attribute :discord_access_token, :string, default: nil
    # attribute :discord_refresh_token, :string, default: nil
    # attribute :steam_uid, :string, default: nil
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime
    discord_id { user[:id] }
    discord_username { user[:name] }
    discord_discriminator { user[:discriminator] }
    steam_uid { user[:steam_uid] }

    # Tracks the type of guild the user has joined
    # :primary for Exile Server Manager, :secondary for my test server
    GUILD_TYPE { :primary }

    before(:create) do |user, evaluator|
      next if evaluator.not_user.nil?

      # Create another user that isn't the discord ID passed in
      new_user = evaluator.users.reject { |u| u[:id] == evaluator.not_user.discord_id }.sample
      user.discord_id = new_user[:id]
      user.discord_username = new_user[:name]
      user.discord_discriminator = new_user[:discriminator]
      user.steam_uid = new_user[:steam_uid]
      # user.steam_username = new_user[:steam_username]
    end

    trait :unregistered do
      steam_uid { nil }
    end

    factory :esm_dev do
      discord_id { TestUser::User1::ID }
      discord_username { TestUser::User1::USERNAME }
      discord_discriminator { TestUser::User1::DISCRIMINATOR }
      steam_uid { TestUser::User1::STEAM_UID }
      # steam_username { TestUser::User1::STEAM_USERNAME }
      GUILD_TYPE { :primary }
    end

    # These users are only on my test discord server
    # Attempting to simulate a different community/user set
    factory :secondary_user do
      transient do
        secondary_user do
          [
            {
              id: TestUser::User2::ID,
              name: TestUser::User2::USERNAME,
              discriminator: TestUser::User2::DISCRIMINATOR,
              steam_uid: TestUser::User2::STEAM_UID,
              steam_username: TestUser::User2::STEAM_USERNAME
            },
            {
              id: TestUser::User3::ID,
              name: TestUser::User3::USERNAME,
              discriminator: TestUser::User3::DISCRIMINATOR,
              steam_uid: TestUser::User3::STEAM_UID,
              steam_username: TestUser::User3::STEAM_USERNAME
            }
          ].sample
        end
      end

      discord_id { secondary_user[:id] }
      discord_username { secondary_user[:name] }
      discord_discriminator { secondary_user[:discriminator] }
      steam_uid { secondary_user[:steam_uid] }
      # steam_username { secondary_user[:steam_username] }
      GUILD_TYPE { :secondary }
    end

    factory :user_with_role do
      discord_id { ENV["ROLE_USER_ID"] }
      discord_username { ENV["ROLE_USER_USERNAME"]}
      discord_discriminator { ENV["ROLE_USER_DISCRIMINATOR"] }
      steam_uid { ENV["ROLE_USER_STEAM_UID"] }
      GUILD_TYPE { :primary }
    end
  end
end
