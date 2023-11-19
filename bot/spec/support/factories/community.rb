# frozen_string_literal: true

FactoryBot.define do
  factory :community, class: "ESM::Community" do
    # attribute :community_id, :string
    # attribute :community_name, :text
    # attribute :guild_id, :string
    # attribute :logging_channel_id, :string
    # attribute :log_reconnect_event, :boolean, default: false
    # attribute :log_xm8_event, :boolean, default: true
    # attribute :player_mode_enabled, :boolean, default: true
    # attribute :territory_admin_ids, :json, default: []
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime
    # attribute :deleted_at, :datetime

    factory :esm_community do
      community_id { "esm" }
      community_name { "Exile Server Manager" }
      guild_id { ESM::Community::ESM::ID }
      logging_channel_id { ESM::Community::ESM::SPAM_CHANNEL }
      player_mode_enabled { false }
      role_ids { [] }
    end

    factory :primary_community do
      transient do
        data { ESM::Test.data[:primary] }
        discord_server { ESM.bot.server(data[:server_id]) }
      end

      community_name { discord_server.name }
      guild_id { discord_server.id.to_s }
      logging_channel_id { data[:logging_channel_id] }
      player_mode_enabled { false }
      territory_admin_ids { [] }
      guild_type { :primary }
      role_ids { data[:role_users].map { |u| u[:role_id].to_s } }
      channel_ids { data[:channels].map(&:to_s) }
      everyone_role_id { data[:everyone_role].to_s }
    end

    factory :secondary_community do
      transient do
        data { ESM::Test.data[:secondary] }
        discord_server { ESM.bot.server(data[:server_id]) }
      end

      community_name { discord_server.name }
      guild_id { discord_server.id.to_s }
      logging_channel_id { data[:logging_channel_id] }
      player_mode_enabled { false }
      territory_admin_ids { [] }
      guild_type { :secondary }
      role_ids { data[:role_users].map { |u| u[:role_id].to_s } }
      channel_ids { data[:channels].map(&:to_s) }
      everyone_role_id { data[:everyone_role].to_s }
    end

    trait :player_mode_enabled do
      player_mode_enabled { true }
    end

    trait :player_mode_disabled do
      player_mode_enabled { false }
    end
  end
end
