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
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime

    server_name { "Server - #{Faker::FunnyName.name}" }
    server_ip { Faker::Internet.public_ip_v4_address }
    server_port { "2302" }

    before :create do |server, _evaluator|
      next if server.server_id.present?

      server.server_id = Faker::ESM.server_id(community_id: server.community.community_id)
    end

    after :create do |server, _evaluator|
      # Remove the default
      server.server_rewards.clear

      server.server_setting = create(:server_setting, server_id: server.id)
      server.server_rewards << create(:server_reward, server_id: server.id)
      server.server_mods << create(:server_mod, server_id: server.id)

      server.save!
    end

    factory :esm_malden do
      server_id { "esm_malden" }
      server_name { "Exile Server Manager Test" }
      server_ip { "127.0.0.1" }
      server_port { "2602" }
    end
  end
end
