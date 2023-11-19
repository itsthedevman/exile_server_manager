# frozen_string_literal: true

FactoryBot.define do
  factory :user_notification_preference, class: "ESM::UserNotificationPreference" do
    association :server, factory: :server
    association :user
  end
end
