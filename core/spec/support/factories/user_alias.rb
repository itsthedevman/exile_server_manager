# frozen_string_literal: true

FactoryBot.define do
  factory :user_alias, class: "ESM::UserAlias" do
    association :user
    value { Faker::Alphanumeric.alpha(number: 4) }

    # One of community or server must be set
    # Use traits or pass them explicitly
  end
end
