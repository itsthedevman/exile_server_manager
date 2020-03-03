# frozen_string_literal: true

module ESM
  class CommandConfiguration < ApplicationRecord
    attribute :community_id, :integer
    attribute :command_name, :string
    attribute :enabled, :boolean, default: true
    attribute :cooldown_quantity, :integer, default: 2
    attribute :cooldown_type, :string, default: "seconds"
    attribute :allowed_in_text_channels, :boolean, default: true
    attribute :whitelist_enabled, :boolean, default: false
    attribute :whitelisted_role_ids, :json, default: []
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :community
  end
end
