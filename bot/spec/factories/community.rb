# frozen_string_literal: true

FactoryBot.define do
  factory :community, class: "ESM::Community" do
    # attribute :community_id, :string
    # attribute :community_name, :text
    # attribute :community_website, :text
    # attribute :guild_id, :string
    # attribute :logging_channel_id, :string
    # attribute :log_reconnect_event, :boolean, default: false
    # attribute :log_xm8_event, :boolean, default: true
    # attribute :player_mode_enabled, :boolean, default: true
    # attribute :territory_admin_ids, :json, default: []
    # attribute :command_prefix, :string, default: nil
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime
    # attribute :deleted_at, :datetime

    factory :esm_community do
      community_id { "esm" }
      community_name { "Exile Server Manager" }
      community_website { "https://www.esmbot.com" }
      guild_id { ESM::Community::ESM::ID }
      logging_channel_id { ESM::Community::ESM::SPAM_CHANNEL }
      player_mode_enabled { false }
    end

    factory :secondary_community do
      community_name { Faker::Company.name }
      guild_id { ESM::Community::Secondary::ID }
      logging_channel_id { ESM::Community::ESM::SPAM_CHANNEL }
      player_mode_enabled { false }
    end

    trait :player_mode_enabled do
      player_mode_enabled { true }
    end

    trait :player_mode_disabled do
      player_mode_enabled { false }
    end
  end
end
