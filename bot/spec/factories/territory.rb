# frozen_string_literal: true

FactoryBot.define do
  factory :territory, class: "ESM::Territory" do
    # attribute :server_id, :integer
    # attribute :territory_level, :integer
    # attribute :territory_purchase_price, :integer
    # attribute :territory_radius, :integer
    # attribute :territory_object_count, :integer
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime

    server_id {}
    territory_level {}
    territory_purchase_price { territory_level * 10 }
    territory_radius { 30 * territory_level }
    territory_object_count { 15 * territory_level }
  end
end
