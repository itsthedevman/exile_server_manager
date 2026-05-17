# frozen_string_literal: true

FactoryBot.define do
  factory :server_mod, class: "ESM::ServerMod" do
    association :server, factory: :server

    mod_name { Faker::Lorem.word }
  end
end
