# frozen_string_literal: true

FactoryBot.define do
  factory :server, class: "ESM::Server" do
    association :community

    server_name { "Server - #{Faker::Lorem.word.capitalize}" }
    server_ip { Faker::Internet.ip_v4_address }
    server_port { "2302" }

    before(:create) do |server|
      server.public_id ||= SecureRandom.uuid
      server.server_key ||= SecureRandom.hex(32)
      server.server_id ||= "#{server.community.community_id}_#{Faker::Alphanumeric.alpha(number: 6)}"
    end

    # Skip after_create callbacks that create associated records
    # We'll create them manually when needed
    after(:build) do |server|
      server.class.skip_callback(:create, :after, :create_server_setting, raise: false)
      server.class.skip_callback(:create, :after, :create_default_reward, raise: false)
    end

    after(:create) do |server|
      # Re-enable callbacks for future factories
      server.class.set_callback(:create, :after, :create_server_setting, raise: false)
      server.class.set_callback(:create, :after, :create_default_reward, raise: false)
    end

    trait :with_setting do
      after(:create) do |server|
        create(:server_setting, server: server)
      end
    end

    trait :with_reward do
      after(:create) do |server|
        create(:server_reward, server: server)
      end
    end

    trait :with_callbacks do
      after(:build) do |server|
        # Re-enable callbacks that were skipped
        server.class.set_callback(:create, :after, :create_server_setting)
        server.class.set_callback(:create, :after, :create_default_reward)
      end
    end
  end
end
