# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      not_user {}
      users do
        [
          {
            id: "264594717939859457",
            name: "[XIII]Bujinkan",
            discriminator: "#3232",
            steam_uid: "76561198016566903",
            steam_username: "[XIII]Bujinkan"
          },
          {
            id: "277499365105467392",
            name: "Beshire",
            discriminator: "#1438",
            steam_uid: "76561198059584856",
            steam_username: "Beshire"
          },
          {
            id: "126909638418366464",
            name: "Bork/Gray",
            discriminator: "#4835",
            steam_uid: "76561198420214659",
            steam_username: "[PE-ARMA.com] novagr94"
          },
          {
            id: "192933241416581120",
            name: "Sea𝗇",
            discriminator: "#0333",
            steam_uid: "76561198133325593",
            steam_username: "Sean"
          },
          {
            id: "247920363025989662",
            name: "SniperMuny",
            discriminator: "#6573",
            steam_uid: "76561198156367625",
            steam_username: "snipermunyshotz"
          },
          {
            id: "233373237860368384",
            name: "Monkeynutz",
            discriminator: "#2010",
            steam_uid: "76561198068913592",
            steam_username: "[GADD] Monkeynutz"
          },
          {
            id: "156139464068956160",
            name: "SkellyKing",
            discriminator: "#0001",
            steam_uid: "76561198096031162",
            steam_username: "Jack(ジャック)"
          },
          {
            id: "473339637679652865",
            name: "Thomas",
            discriminator: "#6538",
            steam_uid: "76561198040955934",
            steam_username: "sobepunk"
          },
          {
            id: "305297279110348801",
            name: "[Z] EnDoh420",
            discriminator: "#5585",
            steam_uid: "76561198081382576",
            steam_username: "EnDoh420"
          },
          {
            id: "283036855220305920",
            name: "chaveezy",
            discriminator: "#3822",
            steam_uid: "76561198065529208",
            steam_username: "ChavezArmy"
          },
          {
            id: "116703422295572484",
            name: "ElmoBlatch",
            discriminator: "#9546",
            steam_uid: "76561197972688089",
            steam_username: "ElmoBlatch"
          },
          {
            id: "361146313905012738",
            name: "Russ",
            discriminator: "#6805",
            steam_uid: "76561198310067286",
            steam_username: "Russ"
          }
        ]
      end
      user { users.sample }
    end

    # attribute :discord_id, :string
    # attribute :discord_username, :string
    # attribute :discord_discriminator, :string
    # attribute :discord_avatar, :text, default: nil
    # attribute :discord_access_token, :string, default: nil
    # attribute :discord_refresh_token, :string, default: nil
    # attribute :steam_uid, :string, default: nil
    # attribute :steam_username, :string, default: nil
    # attribute :steam_avatar, :text, default: nil
    # attribute :steam_profile_url, :text, default: nil
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime
    discord_id { user[:id] }
    discord_username { user[:name] }
    discord_discriminator { user[:discriminator] }
    steam_uid { user[:steam_uid] }
    steam_username { user[:steam_username] }

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
      user.steam_username = new_user[:steam_username]
    end

    trait :unregistered do
      steam_uid { nil }
      steam_username { nil }
    end

    factory :esm_dev do
      discord_id { ESM::User::Bryan::ID }
      discord_username { ESM::User::Bryan::USERNAME }
      discord_discriminator { ESM::User::Bryan::DISCRIMINATOR }
      steam_uid { ESM::User::Bryan::STEAM_UID }
      steam_username { ESM::User::Bryan::STEAM_USERNAME }
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
      steam_username { secondary_user[:steam_username] }
      GUILD_TYPE { :secondary }
    end

    factory :andrew do
      discord_id { "102537804843593728" }
      discord_username { "Andrew" }
      discord_discriminator { "0693" }
      steam_uid { "76561198025434405" }
      steam_username { "Andrew_S90" }
      GUILD_TYPE { :primary }
    end
  end
end
