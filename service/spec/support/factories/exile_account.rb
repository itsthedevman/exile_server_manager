# frozen_string_literal: true

FactoryBot.define do
  factory :exile_account, class: "ESM::ExileAccount" do
    name { Faker::Name.name }
  end
end
