# frozen_string_literal: true

module ESM
  class CommandConfiguration < ApplicationRecord
    COOLDOWN_TYPES = %w[
      times
      seconds
      minutes
      hours
      days
    ].freeze
    public_constant :COOLDOWN_TYPES

    attribute :community_id, :integer
    attribute :command_name, :string
    attribute :enabled, :boolean, default: true
    attribute :notify_when_disabled, :boolean, default: true
    attribute :cooldown_quantity, :integer, default: 2
    attribute :cooldown_type, :string, default: "seconds"
    attribute :allowed_in_text_channels, :boolean, default: true
    attribute :allowlist_enabled, :boolean, default: false
    attribute :allowlisted_role_ids, :json, default: []
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :community

    def allowlisted_roles
      @allowlisted_roles ||= lambda do
        allowlisted_role_ids.filter_map do |id|
          role = community.roles.find { |r| r.id == id }
          next if role.nil?

          role
        end
      end.call
    end

    def details
      CommandDetail.where(command_name: command_name).first
    end
  end
end
