# frozen_string_literal: true

module ESM
  class ExileXm8Notification < ArmaRecord
    self.inheritance_column = nil
    self.table_name = "xm8_notification"

    attribute :uuid, :string, default: -> { SecureRandom.uuid }
    attribute :recipient_uid, :string
    attribute :territory_id, :integer, default: nil
    attribute :type, :string
    attribute :content, :json
    attribute :state, :string, default: "new"
    attribute :state_details, :string
    attribute :attempt_count, :integer, default: 0
    attribute :created_at, :datetime, default: -> { Time.current }
    attribute :last_attempt_at, :datetime
    attribute :acknowledged_at, :datetime

    belongs_to :account,
      class_name: "ESM::ExileAccount",
      foreign_key: "recipient_uid"

    belongs_to :territory,
      class_name: "ESM::ExileTerritory",
      foreign_key: "territory_id",
      optional: true

    scope :failed, -> { order(state: :asc).where(state: "failed") }
    scope :sent, -> { order(state: :asc).where(state: "sent") }

    scope :base_raid, -> { where(type: "base-raid") }
    scope :charge_plant_started, -> { where(type: "charge-plant-started") }
    scope :custom, -> { where(type: "custom") }
    scope :flag_restored, -> { where(type: "flag-restored") }
    scope :flag_steal_started, -> { where(type: "flag-steal-started") }
    scope :flag_stolen, -> { where(type: "flag-stolen") }
    scope :grind_started, -> { where(type: "grind-started") }
    scope :hack_started, -> { where(type: "hack-started") }
    scope :marxet_item_sold, -> { where(type: "marxet-item-sold") }
    scope :protection_money_due, -> { where(type: "protection-money-due") }
    scope :protection_money_paid, -> { where(type: "protection-money-paid") }
  end
end
