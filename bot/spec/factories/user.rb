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
      discord_id { ESM::User::Bryan::ID }
      discord_username { ESM::User::Bryan::USERNAME }
      discord_discriminator { ESM::User::Bryan::DISCRIMINATOR }
      steam_uid { ESM::User::Bryan::STEAM_UID }
      # steam_username { ESM::User::Bryan::STEAM_USERNAME }
      GUILD_TYPE { :primary }
    end

    # These users are only on my test discord server
    # Attempting to simulate a different community/user set
    factory :secondary_user do
      transient do
        secondary_user do
          [
            {
              id: ESM::User::BryanV2::ID,
              name: ESM::User::BryanV2::USERNAME,
              discriminator: ESM::User::BryanV2::DISCRIMINATOR,
              steam_uid: ESM::User::BryanV2::STEAM_UID,
              steam_username: ESM::User::BryanV2::STEAM_USERNAME
            },
            {
              id: ESM::User::BryanV3::ID,
              name: ESM::User::BryanV3::USERNAME,
              discriminator: ESM::User::BryanV3::DISCRIMINATOR,
              steam_uid: ESM::User::BryanV3::STEAM_UID,
              steam_username: ESM::User::BryanV3::STEAM_USERNAME
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

    factory :andrew do
      discord_id { "102537804843593728" }
      discord_username { "Andrew" }
      discord_discriminator { "0693" }
      steam_uid { "76561198025434405" }
      # steam_username { "Andrew_S90" }
      GUILD_TYPE { :primary }
    end
  end
end
