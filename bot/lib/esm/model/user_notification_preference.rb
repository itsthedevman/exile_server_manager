# frozen_string_literal: true

module ESM
  class UserNotificationPreference < ApplicationRecord
    attribute :user_id, :integer
    attribute :server_id, :integer
    attribute :base_raid, :boolean, default: true
    attribute :charge_plant_started, :boolean, default: true
    attribute :custom, :boolean, default: true
    attribute :flag_restored, :boolean, default: true
    attribute :flag_steal_started, :boolean, default: true
    attribute :flag_stolen, :boolean, default: true
    attribute :grind_started, :boolean, default: true
    attribute :hack_started, :boolean, default: true
    attribute :protection_money_due, :boolean, default: true
    attribute :protection_money_paid, :boolean, default: true

    belongs_to :user
    belongs_to :server
  end
end
