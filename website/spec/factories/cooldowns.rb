# frozen_string_literal: true

FactoryBot.define do
  factory :cooldown, class: "ESM::Cooldown" do
    community
    command_name { "me" }
    cooldown_quantity { 2 }
    cooldown_type { "seconds" }
    expires_at { 1.second.ago }

    # The default is already spent, which is the useful default for a row that just needs to exist. This is the one
    # that is still standing between the player and the command.
    trait :active do
      expires_at { 10.minutes.from_now }
    end
  end
end
