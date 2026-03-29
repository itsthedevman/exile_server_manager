# frozen_string_literal: true

FactoryBot.define do
  factory :community_default, class: "ESM::CommunityDefault" do
    association :community
    association :server
    # channel_id is optional - nil means global default
  end
end
