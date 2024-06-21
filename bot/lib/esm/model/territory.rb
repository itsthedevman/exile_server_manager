# frozen_string_literal: true

module ESM
  class Territory < ApplicationRecord
    attribute :server_id, :integer
    attribute :territory_level, :integer # Offset by 1 (exile counts 0 as the first level)
    attribute :territory_purchase_price, :integer, limit: 8
    attribute :territory_radius, :integer
    attribute :territory_object_count, :integer
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server
  end
end
