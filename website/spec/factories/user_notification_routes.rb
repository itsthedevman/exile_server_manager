# frozen_string_literal: true

FactoryBot.define do
  factory :user_notification_route, class: "ESM::UserNotificationRoute" do
    association :destination_community, factory: :community
    user

    public_id { SecureRandom.uuid }
    channel_id { "700000000000000001" }
    source_server_id { nil }
    notification_type { "base-raid" }
    enabled { true }
    user_accepted { true }
    community_accepted { true }
  end
end
