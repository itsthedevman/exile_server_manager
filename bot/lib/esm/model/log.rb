# frozen_string_literal: true

module ESM
  class Log < ApplicationRecord
    before_create :generate_uuid
    before_create :set_expiration_date

    attribute :uuid, :uuid
    attribute :server_id, :integer
    attribute :search_text, :text
    attribute :requestors_user_id, :string
    attribute :expires_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server
    has_many :log_entries, dependent: :destroy

    def link
      if ESM.env.production?
        "https://www.esmbot.com/logs/#{uuid}"
      else
        "http://localhost:3000/logs/#{uuid}"
      end
    end

    private

    def generate_uuid
      self.uuid = SecureRandom.uuid
    end

    def set_expiration_date
      self.expires_at = 1.day.from_now.utc
    end
  end
end
