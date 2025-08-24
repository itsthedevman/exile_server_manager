# frozen_string_literal: true

module ESM
  class UserAlias < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :uuid, :uuid
    attribute :user_id, :integer
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :value, :string
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    alias_attribute :public_id, :uuid

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :user
    belongs_to :community, optional: true
    belongs_to :server, optional: true

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    validates :value, presence: true, length: {in: 1..64}
    validate :value_unique_within_scope

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    before_validation(on: :create) { self.uuid ||= SecureRandom.uuid }

    # =============================================================================
    # SCOPES
    # =============================================================================

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

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

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    private

    def value_unique_within_scope
      return if value.blank?

      # Check for data integrity first
      if server_id.present? && community_id.present?
        errors.add(:base, "Alias cannot belong to both a server and community")
        return
      elsif server_id.blank? && community_id.blank?
        errors.add(:base, "Alias must belong to either a server or community")
        return
      end

      # Now do the actual uniqueness check
      query = self.class.where(
        user_id:,
        value:,
        server_id: server_id.presence,
        community_id: community_id.presence
      )

      query = query.where.not(id:) if persisted?
      errors.add(:value, "already exists") if query.exists?
    end
  end
end
