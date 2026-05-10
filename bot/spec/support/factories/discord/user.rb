# frozen_string_literal: true

FactoryBot.define do
  factory :discord_user, class: "Discordrb::User" do
    skip_create

    transient do
      id { ESM::Test::Snowflake.next }
      username { Faker::Internet.username(specifier: 6..16) }
      bot_account { false }
    end

    initialize_with do
      Discordrb::User.new(
        {
          "id" => id,
          "username" => username,
          "global_name" => username,
          "discriminator" => "0",
          "avatar" => nil,
          "public_flags" => 0,
          "bot" => bot_account
        },
        ESM.discord_bot
      )
    end

    after(:build) { |user| ESM.discord_bot.cache_user(user) }
  end
end
