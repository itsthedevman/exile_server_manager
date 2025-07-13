# frozen_string_literal: true

module ESM
  class UserAlias < ApplicationRecord
    before_validation(on: :create) { self.uuid ||= SecureRandom.uuid }

    attribute :uuid, :uuid
    attribute :user_id, :integer
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :value, :string

    belongs_to :user
    belongs_to :community, optional: true
    belongs_to :server, optional: true

    validates :uuid, uniqueness: true, presence: true
    validates :value, uniqueness: {scope: [:user_id, :server_id]}
    validates :value, uniqueness: {scope: [:user_id, :community_id]}
    validates :value, length: {minimum: 1, maximum: 64}

    def self.find_server_alias(value)
      eager_load(:server).where(value: value).where.not(server_id: nil).first
    end

    def self.find_community_alias(value)
      eager_load(:community).where(value: value).where.not(community_id: nil).first
    end

    def self.by_type
      eager_load(:community, :server)
        .each_with_object({community: [], server: []}) do |id_alias, hash|
          if id_alias.server
            hash[:server] << id_alias
          elsif id_alias.community
            hash[:community] << id_alias
          end
        end
    end
  end
end
