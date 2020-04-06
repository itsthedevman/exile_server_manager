# frozen_string_literal: true

module ESM
  class BotAttribute < ApplicationRecord
    attribute :maintenance_mode_enabled, :boolean, default: false
    attribute :maintenance_message, :string, default: nil
    attribute :status_type, :string, default: "PLAYING"
    attribute :status_message, :string, default: "!register"
    attribute :community_count, :integer, default: 0
    attribute :server_count, :integer, default: 0
    attribute :user_count, :integer, default: 0
  end
end
