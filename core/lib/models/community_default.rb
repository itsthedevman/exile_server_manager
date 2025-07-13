# frozen_string_literal: true

module ESM
  class CommunityDefault < ApplicationRecord
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :channel_id, :string

    belongs_to :community
    belongs_to :server

    def self.global
      where(channel_id: nil).first
    end

    def self.for_channel(channel)
      where(channel_id: channel.id.to_s).first
    end
  end
end
