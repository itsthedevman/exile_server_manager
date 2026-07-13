# frozen_string_literal: true

FactoryBot.define do
  factory :server_command, class: "ESM::ServerCommand" do
    user
    server
    command_name { "pay" }
    idempotency_key { SecureRandom.uuid }
    status { "pending" }
    arguments { {} }
  end
end
