# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      user do
        user_id = ESM::Test.data[:primary][:users].sample
        discord_user = ESM.bot.user(user_id)

        {
          id: user_id,
          name: discord_user.username,
          discriminator: discord_user.discriminator,
          steam_uid: ESM::Test.steam_uid
        }
      end
    end

    discord_id { user[:id] }
    discord_username { user[:name] }
    discord_discriminator { user[:discriminator] }
    steam_uid { user[:steam_uid] }
    guild_type { :primary }

    trait :unregistered do
      steam_uid { nil }
    end

    factory :developer do
      transient do
        user { ESM::Test.data[:dev] }
        discord_user { ESM.bot.user(user[:id]) }
      end

      discord_id { user[:id] }
      discord_username { discord_user.username }
      discord_discriminator { discord_user.discriminator }
      steam_uid { user[:steam_uid] }
      guild_type { :primary }
    end

    factory :secondary_user do
      transient do
        user do
          user_id = ESM::Test.data[:secondary][:users].sample
          discord_user = ESM.bot.user(user_id)

          {
            id: user_id,
            name: discord_user.username,
            discriminator: discord_user.discriminator,
            steam_uid: ESM::Test.steam_uid
          }
        end
      end

      discord_id { user[:id] }
      discord_username { user[:name] }
      discord_discriminator { user[:discriminator] }
      steam_uid { user[:steam_uid] }
      guild_type { :secondary }
    end

    trait :with_role do
      transient do
        user do
          user_data = ESM::Test.data[guild_type][:role_users].sample
          discord_user = ESM.bot.user(user_data[:id])

          user_data.merge(
            name: discord_user.username,
            discriminator: discord_user.discriminator,
            role_id: user_data[:role_id]
          )
        end
      end

      discord_id { user[:id] }
      discord_username { user[:name] }
      discord_discriminator { user[:discriminator] }
      role_id { user[:role_id] }
    end
  end
end
