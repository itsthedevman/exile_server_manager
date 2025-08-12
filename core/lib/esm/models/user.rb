# frozen_string_literal: true

module ESM
  class User < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :discord_id, :string
    attribute :discord_username, :string
    attribute :discord_avatar, :text, default: nil
    attribute :discord_access_token, :string, default: nil
    attribute :discord_refresh_token, :string, default: nil
    attribute :steam_uid, :string, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    alias_attribute :avatar_url, :discord_avatar
    alias_attribute :distinct, :discord_username
    alias_attribute :username, :discord_username

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    has_many :cooldowns, dependent: :nullify
    has_many :id_aliases, class_name: "UserAlias", dependent: :destroy
    has_one :id_defaults, class_name: "UserDefault", dependent: :destroy
    has_many :logs, class_name: "Log", foreign_key: "requestors_user_id", dependent: :destroy
    has_many :my_requests, foreign_key: :requestor_user_id, class_name: "Request", dependent: :destroy
    has_many :pending_requests, foreign_key: :requestee_user_id, class_name: "Request", dependent: :destroy
    has_many :user_gamble_stats, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy
    has_many :user_notification_routes, dependent: :destroy
    has_one :user_steam_data, dependent: :destroy
    has_many :user_steam_uid_history, dependent: :nullify

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    after_create :create_user_steam_data
    after_create :create_id_defaults

    after_save :insert_steam_uid_history

    # =============================================================================
    # SCOPES
    # =============================================================================

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    def self.find_by_steam_uid(uid)
      order(:steam_uid).where(steam_uid: uid).first
    end

    def self.find_by_discord_id(id)
      id = id.to_s unless id.is_a?(String)
      order(:discord_id).where(discord_id: id).first
    end

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def attributes_for_logging
      attributes.except(
        "id", "discord_avatar", "discord_access_token",
        "discord_refresh_token", "updated_at"
      )
    end

    def steam_data
      @steam_data ||= user_steam_data&.refresh
    end

    def registered?
      steam_uid.present?
    end

    def mention
      "<@#{discord_id}>"
    end

    alias_method :discord_mention, :mention

    def deregister!
      update!(steam_uid: nil)
      user_steam_data.update!(
        username: nil,
        avatar: nil,
        profile_url: nil,
        profile_visibility: nil,
        profile_created_at: nil,
        community_banned: nil,
        vac_banned: nil,
        number_of_vac_bans: nil,
        days_since_last_ban: nil,
        updated_at: 30.minutes.ago
      )
    end

    private

    def insert_steam_uid_history
      return unless changes.key?(:steam_uid)

      user_steam_uid_history.create!(
        previous_steam_uid: changes[:steam_uid].first,
        new_steam_uid: changes[:steam_uid].second
      )
    end
  end
end
