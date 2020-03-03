# frozen_string_literal: true

FactoryBot.define do
  factory :server, class: "ESM::Server" do
    # attribute :server_id, :string
    # attribute :community_id, :integer
    # attribute :server_name, :text
    # attribute :server_key, :text
    # attribute :server_ip, :string
    # attribute :server_port, :string
    # attribute :server_start_time, :datetime
    # attribute :is_premium, :boolean, default: false
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime

    server_id {}
    server_name { Faker::FunnyName.name }
    server_ip { Faker::Internet.public_ip_v4_address }
    server_port { "2302" }
    server_start_time { DateTime.now }

    before :create do |server, _evaluator|
      next if server.server_id.present?

      server.server_id = "#{server.community.community_id}_#{Faker::NatoPhoneticAlphabet.code_word.downcase}"
    end

    after :create do |server, _evaluator|
      server.server_reward = create(:server_reward, server_id: server.id)
      server.server_setting = create(:server_setting, server_id: server.id)

      1..10.times.each do |i|
        create(:territory, territory_level: i, server_id: server.id)
      end
    end

    factory :esm_malden do
      server_id { "esm_malden" }
      server_name { "Exile Server Manager Test" }
      server_ip { "127.0.0.1" }
      server_port { "2602" }
      server_start_time { DateTime.now }
    end

    trait :premium_enabled do
      is_premium { true }
    end

    trait :premium_disabled do
      is_premium { false }
    end
  end
end
