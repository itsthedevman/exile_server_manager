# frozen_string_literal: true

FactoryBot.define do
  factory :discord_channel, class: "Discordrb::Channel" do
    skip_create

    transient do
      id { ESM::Test::Snowflake.next }
      name { Faker::Internet.username(specifier: 6..16) }
      server { nil }
      # Discord channel types: 0 = text, 1 = DM, 2 = voice, 5 = announcement, ...
      channel_type { 0 }
      position { 0 }
    end

    initialize_with do
      Discordrb::Channel.new(
        {
          "id" => id,
          "name" => name,
          "type" => channel_type,
          "position" => position,
          "guild_id" => server&.id
        },
        ESM.discord_bot,
        server
      )
    end

    after(:build) do |channel, evaluator|
      ESM.discord_bot.cache_channel(channel)
      evaluator.server&.add_channel(channel)
    end
  end
end
