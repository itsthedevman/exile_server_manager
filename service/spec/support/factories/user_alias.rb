# frozen_string_literal: true

FactoryBot.define do
  factory :user_alias, class: "ESM::UserAlias" do
    # attribute :user_id, :integer
    # attribute :community_id, :integer
    # attribute :server_id, :integer
    value { Faker::Alphanumeric.alpha(number: 4) }

    # belongs_to :user
    # belongs_to :community
    # belongs_to :server
  end
end
