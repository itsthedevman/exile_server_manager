# frozen_string_literal: true

FactoryBot.define do
  factory :user_default, class: "ESM::UserDefault" do
    association :user
    # community and server are optional
  end
end
