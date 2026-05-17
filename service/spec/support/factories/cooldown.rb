# frozen_string_literal: true

FactoryBot.define do
  factory :cooldown, class: "ESM::Cooldown" do
    transient do
      delay {}
    end

    # attribute :command_name, :string
    # attribute :community_id, :integer
    # attribute :server_id, :integer
    # attribute :user_id, :integer
    # attribute :cooldown_quantity, :integer
    # attribute :cooldown_type, :string
    # attribute :cooldown_amount, :integer
    # attribute :expires_at, :datetime
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime
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
