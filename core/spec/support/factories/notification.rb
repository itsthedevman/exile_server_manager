# frozen_string_literal: true

FactoryBot.define do
  factory :notification, class: "ESM::Notification" do
    association :community

    notification_type { ESM::Notification::TYPES.sample }
    notification_category { ESM::Notification::CATEGORIES.sample }
    notification_title { Faker::Lorem.sentence(word_count: 3) }
    notification_description { Faker::Lorem.paragraph }
    notification_color { ESM::Color.random }
  end
end
