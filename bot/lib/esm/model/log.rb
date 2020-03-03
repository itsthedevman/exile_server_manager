# frozen_string_literal: true

module ESM
  class Log < ApplicationRecord
    attribute :uuid, :uuid
    attribute :server_id, :integer
    attribute :search_text, :text
    attribute :requestors_user_id, :string
    attribute :parsed_entries, :json
    attribute :expires_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server
  end
end
