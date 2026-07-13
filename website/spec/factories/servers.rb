# frozen_string_literal: true

FactoryBot.define do
  factory :server, class: "ESM::Server" do
    community
    server_id { "#{community.community_id}_test" }
    server_name { "Test Server" }
    server_ip { "127.0.0.1" }
    server_port { "2302" }
  end
end
