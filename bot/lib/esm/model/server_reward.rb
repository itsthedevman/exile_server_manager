# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    attribute :server_id, :integer
    attribute :reward_items, :json, default: {}
    attribute :player_poptabs, :integer, default: 0
    attribute :locker_poptabs, :integer, default: 0
    attribute :respect, :integer, default: 0

    belongs_to :server
  end
end
