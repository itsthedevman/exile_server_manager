# frozen_string_literal: true

FactoryBot.define do
  factory :cooldown, class: "ESM::Cooldown" do
    transient do
      delay { nil }
    end

    command_name { "base" }
    cooldown_quantity { 2 }
    cooldown_type { "seconds" }
    expires_at { 1.second.ago }

    trait :inactive do
      command_name { "base" }
      cooldown_quantity { 10 }
      cooldown_type { "seconds" }
      expires_at { 1.second.ago }
    end

    trait :active do
      command_name { "base" }
      cooldown_quantity { 10 }
      cooldown_type { "seconds" }
      expires_at { 1.second.ago + (delay || 11.seconds) }
    end
  end
end
