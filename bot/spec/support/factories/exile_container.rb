# frozen_string_literal: true

FactoryBot.define do
  factory :exile_container, class: "ESM::ExileContainer" do
    spawned_at { Faker::Date.backward }
    is_locked { false }
    pin_code { "00000" }
    last_updated_at { Time.current }

    after(:build) do |model|
      # FactoryBot was not detecting this, probably because it's an alias
      model.class_name = ESM::Arma::ClassLookup.where(
        mod: "exile",
        category: "exile_container"
      ).keys.sample
    end
  end
end
