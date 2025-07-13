# frozen_string_literal: true

class ApiToken < ApplicationRecord
  attribute :token, :string
  attribute :active, :boolean, default: true
  attribute :comment, :string
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  before_save :create_token

  private

  def create_token
    self.token = SecureRandom.uuid.delete("-").upcase
  end
end
