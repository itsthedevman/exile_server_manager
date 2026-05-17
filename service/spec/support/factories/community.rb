# frozen_string_literal: true

FactoryBot.define do
  factory :community, class: "ESM::Community" do
    transient do
      discord_server { build(:discord_server, channels: [:logging]) }
      logging_channel { discord_server.channels.find { |c| c.name == "logging" } || discord_server.channels.first }
    end

    community_name { discord_server.name }
    guild_id { discord_server.id.to_s }
    logging_channel_id { logging_channel&.id&.to_s }
    player_mode_enabled { false }
    territory_admin_ids { [] }
    role_ids { discord_server.roles.reject { |role| role.id == discord_server.id }.map { |role| role.id.to_s } }
    channel_ids { discord_server.channels.map { |channel| channel.id.to_s } }
    everyone_role_id { discord_server.everyone_role.id.to_s }

    factory :esm_community do
      community_id { "esm" }
      community_name { "Exile Server Manager" }
      role_ids { [] }
    end

    trait :player_mode_enabled do
      player_mode_enabled { true }
    end

    trait :player_mode_disabled do
      player_mode_enabled { false }
    end
  end
end
