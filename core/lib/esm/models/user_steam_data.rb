# frozen_string_literal: true

module ESM
  class UserSteamData < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # How long Steam's answer is trusted before it is asked again. Shared by the persisted rows and by the detached
    # ones .from_steam_uid builds, so both halves of #steam_data go stale on the same schedule.
    REFRESH_INTERVAL = 15.minutes

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :user_id, :integer
    attribute :username, :string, default: nil
    attribute :avatar, :text, default: nil
    attribute :profile_url, :text, default: nil
    attribute :profile_visibility, :string, default: nil
    attribute :profile_created_at, :datetime, default: nil
    attribute :community_banned, :boolean, default: false
    attribute :vac_banned, :boolean, default: false
    attribute :number_of_vac_bans, :integer, default: 0
    attribute :days_since_last_ban, :integer, default: 0
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    # A row built by .from_steam_uid has no user, so it reports `valid? == false` no matter how complete its Steam
    # data is. That is ActiveRecord's meaning of valid, not "Steam answered" - ask #username or the like for that.
    belongs_to :user

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    # =============================================================================
    # SCOPES
    # =============================================================================

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    ##
    # Builds a detached, read-only row for a Steam UID that has no ESM account behind it.
    #
    # ESM::User answers #steam_data with its persisted row and ESM::User::Ephemeral answers with one of these, so
    # callers get one type either way. There is no user for it to belong to, so it is never saved.
    #
    # @param steam_uid [String] the Steam UID to look up
    #
    # @return [ESM::UserSteamData] an unsaved, read-only row. Its fields are nil when Steam has nothing to say
    #
    def self.from_steam_uid(steam_uid)
      # skip_nil keeps a failed lookup out of the cache so the next caller asks again, matching how #refresh leaves
      # updated_at alone when Steam does not answer.
      attributes = ESM.cache.fetch(
        steam_uid_cache_key(steam_uid),
        expires_in: REFRESH_INTERVAL,
        skip_nil: true
      ) do
        account = ESM::SteamAccount.new(steam_uid)
        account.to_h if account.valid?
      end

      new(attributes || {}).tap(&:readonly!)
    end

    # Namespaced on the shared ESM keyspace, which the bot and the website both read, so a lookup on one side warms
    # the other.
    def self.steam_uid_cache_key(steam_uid)
      "user_steam_data:#{steam_uid}"
    end

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    # The shape the website reads. ESM::SteamAccount#to_h is its counterpart on the way in, keyed to these same
    # attribute names so it can be handed straight to .new and #update.
    def to_h
      {
        username:,
        avatar:,
        profile_url:,
        profile_visibility:,
        profile_created_at:,
        community_banned:,
        vac_banned:,
        number_of_vac_bans:,
        days_since_last_ban:
      }
    end

    def refresh
      # .from_steam_uid rows have no user to refresh against and no updated_at to measure staleness with. They were
      # built from Steam moments ago (or from a cache entry younger than REFRESH_INTERVAL), so they are already current.
      return self if readonly?
      return self unless needs_refresh?
      return self if user.steam_uid.blank?

      player_data = ESM::SteamAccount.new(user.steam_uid)
      return self unless player_data.valid?

      update(player_data.to_h)

      self
    end

    def needs_refresh?
      (ESM::Time.now - updated_at) >= REFRESH_INTERVAL
    end
  end
end
