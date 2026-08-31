# frozen_string_literal: true

FactoryBot.define do
  factory :cooldown, class: "ESM::Cooldown" do
    community
    command_name { "me" }
    cooldown_quantity { 2 }
    cooldown_type { "seconds" }
    expires_at { 1.second.ago }
  end
end
