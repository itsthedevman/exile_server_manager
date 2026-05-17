# frozen_string_literal: true

module ESM
  class ExileConstruction < ArmaRecord
    include ClassColumnSupport

    self.table_name = "construction"

    attribute :account_uid, :string
    attribute :spawned_at, :datetime
    attribute :position_x, :float
    attribute :position_y, :float
    attribute :position_z, :float
    attribute :direction_x, :float
    attribute :direction_y, :float
    attribute :direction_z, :float
    attribute :up_x, :float
    attribute :up_y, :float
    attribute :up_z, :float
    attribute :is_locked, :boolean
    attribute :pin_code, :string
    attribute :damage, :boolean
    attribute :territory_id, :integer
    attribute :last_updated_at, :datetime
    attribute :deleted_at, :datetime

    belongs_to :territory, inverse_of: :constructions

    validates :class_name, :account_uid, :territory_id, presence: true
  end
end
