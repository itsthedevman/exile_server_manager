# frozen_string_literal: true

FactoryBot.define do
  factory :server_setting, class: "ESM::ServerSetting" do
    association :server

    # All defaults are defined in the model
  end
end
