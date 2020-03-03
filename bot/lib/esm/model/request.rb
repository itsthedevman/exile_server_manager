# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    attribute :user_id, :integer
    attribute :request_name, :string
    attribute :request_metadata, :json, default: nil
    attribute :expires_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :user
  end
end
