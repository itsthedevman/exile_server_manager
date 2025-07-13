# frozen_string_literal: true

class UserSteamUidHistory < ApplicationRecord
  attribute :previous_steam_uid, :string
  attribute :new_steam_uid, :string
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  belongs_to :user, optional: true
end
