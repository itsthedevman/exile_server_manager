# frozen_string_literal: true

FactoryBot.define do
  factory :service_command, class: "ESM::ServiceCommand" do
    user
    server
    community { server.community }
    command_name { "pay" }
    idempotency_key { SecureRandom.uuid }
    status { "pending" }
    arguments { {} }
  end
end
