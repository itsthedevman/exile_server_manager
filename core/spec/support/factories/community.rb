# frozen_string_literal: true

FactoryBot.define do
  factory :community, class: "ESM::Community" do
    community_name { Faker::Company.name }
    guild_id { Faker::Number.number(digits: 18).to_s }
    player_mode_enabled { false }

    # Generate required fields before creation
    before(:create) do |community|
      community.community_id ||= Array.new(4) { ("a".."z").to_a.sample }.join
      community.public_id ||= SecureRandom.uuid
    end

    # Skip after_create callbacks that depend on bot-specific code
    after(:build) do |community|
      community.class.skip_callback(:create, :after, :create_command_configurations, raise: false)
      community.class.skip_callback(:create, :after, :create_notifications, raise: false)
    end

    after(:create) do |community|
      # Re-enable callbacks for future factories
      community.class.set_callback(:create, :after, :create_command_configurations, raise: false)
      community.class.set_callback(:create, :after, :create_notifications, raise: false)
    end
  end
end
