# frozen_string_literal: true

FactoryBot.define do
  factory :user_notification_route, class: "ESM::UserNotificationRoute" do
    association :destination_community, factory: :community
    # association :source_server, factory: :server # The server requires a community
    association :user

    public_id { SecureRandom.uuid }
    source_server_id { nil }
    notification_type { "base-raid" }
    enabled { true }
    user_accepted { true }
    community_accepted { true }

    trait :not_accepted do
      user_accepted { false }
      community_accepted { false }
    end
  end
end
