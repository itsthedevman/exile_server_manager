# frozen_string_literal: true

module ESM
  class Cooldown < ApplicationRecord
    attribute :command_name, :string
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :user_id, :integer
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string
    attribute :cooldown_amount, :integer
    attribute :expires_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :user
    belongs_to :server
    belongs_to :community

    def active?
      expires_at >= DateTime.now
    end

    def to_s
      ESM::Time.distance_of_time_in_words(expires_at)
    end

    def reset!
      update!(expires_at: 1.second.ago)
    end
  end
end
