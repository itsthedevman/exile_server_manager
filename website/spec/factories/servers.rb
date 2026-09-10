# frozen_string_literal: true

FactoryBot.define do
  factory :server, class: "ESM::Server" do
    community
    server_id { "#{community.community_id}_test" }
    server_name { "Test Server" }
    server_ip { "127.0.0.1" }
    server_port { "2302" }

    # A server with no version reads as 1.0.0, which every player surface now refuses. The interesting default is a
    # server new enough to use, so a spec about anything else does not have to say so; one testing the gate itself
    # sets an older version on purpose.
    server_version { ServerVersion::MINIMUM_SERVER_VERSION }
  end
end
