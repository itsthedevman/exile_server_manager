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

    server_name { Faker::FunnyName.name }
    server_ip { Faker::Internet.public_ip_v4_address }
    server_port { "2302" }

    before :create do |server, _evaluator|
      next if server.server_id.present?

      server_id =
        loop do
          server_id = Faker::ESM.server_id(community_id: server.community.community_id)
          break server_id if ESM::Server.find_by_server_id(server_id).nil?
        end

      server.server_id = server_id
    end

    after :create do |server, _evaluator|
      # Remove the default
      server.server_rewards.clear

      server.server_setting = create(:server_setting, server_id: server.id)
      server.server_rewards << create(:server_reward, server_id: server.id)

      server.save!

      # Store the server key so the build tool can pick it up and write it
      Redis.new.set("server_key", server.token.to_json)
    end

    factory :esm_malden do
      server_id { "esm_malden" }
      server_name { "Exile Server Manager Test" }
      server_ip { "127.0.0.1" }
      server_port { "2602" }
    end
  end
end
