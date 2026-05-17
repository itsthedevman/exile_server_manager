# frozen_string_literal: true

module ESM
  class ExileContainer < ArmaRecord
    include ClassColumnSupport

    self.table_name = "container"

    attribute :spawned_at, :datetime
    attribute :account_uid, :string
    attribute :is_locked, :boolean
    attribute :position_x, :float
    attribute :position_y, :float
    attribute :position_z, :float
    attribute :direction_x, :float
    attribute :direction_y, :float
    attribute :direction_z, :float
    attribute :up_x, :float
    attribute :up_y, :float
    attribute :up_z, :float
    attribute :cargo_items, :json, default: []
    attribute :cargo_magazines, :json, default: []
    attribute :cargo_weapons, :json, default: []
    attribute :cargo_container, :json, default: []
    attribute :last_updated_at, :datetime
    attribute :pin_code, :string
    attribute :territory_id, :integer
    attribute :deleted_at, :datetime
    attribute :money, :string
    attribute :abandoned, :datetime

    belongs_to :territory, inverse_of: :containers

    validates :class_name, :account_uid, :territory_id, presence: true
  end
end
