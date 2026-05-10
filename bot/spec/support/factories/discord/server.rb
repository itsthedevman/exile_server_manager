# frozen_string_literal: true

FactoryBot.define do
  factory :discord_server, class: "Discordrb::Server" do
    skip_create

    transient do
      id { ESM::Test::Snowflake.next }
      name { Faker::Company.name }
      owner { build(:discord_user) }
      # Symbols or strings; built into channels after the server exists.
      channels { [] }
      # Symbols or strings; built into roles after the server exists.
      roles { [] }
    end

    initialize_with do
      # @everyone always shares the server ID. Server expects `@roles[@id]`
      # to be the everyone role; seeding it here means specs don't have to.
      everyone_role = {
        "id" => id,
        "name" => "@everyone",
        "permissions" => "0",
        "position" => 0,
        "hoist" => false,
        "mentionable" => false,
        "managed" => false,
        "colors" => {"primary_color" => 0},
        "flags" => 0
      }

      Discordrb::Server.new(
        {
          "id" => id,
          "name" => name,
          "owner_id" => owner.id.to_s,
          "afk_timeout" => 300,
          "roles" => [everyone_role],
          "member_count" => 0
        },
        ESM.discord_bot
      )
    end

    after(:build) do |server, evaluator|
      ESM.discord_bot.cache_user(evaluator.owner)
      build(:discord_member, server: server, user: evaluator.owner)

      evaluator.roles.each { |role_name| build(:discord_role, server: server, name: role_name.to_s) }
      evaluator.channels.each { |channel_name| build(:discord_channel, server: server, name: channel_name.to_s) }

      # Discordrb::Server#members blocks on a gateway chunk request unless
      # @chunked is true. We've populated everything we care about already.
      server.instance_variable_set(:@chunked, true)

      ESM.discord_bot.cache_server(server)
    end
  end
end
