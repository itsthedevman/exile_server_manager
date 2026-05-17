# frozen_string_literal: true

FactoryBot.define do
  factory :exile_xm8_notification, class: "ESM::ExileXm8Notification" do
    type { "custom" }
    content { {title: "Test title"}.to_json }
  end
end
