# frozen_string_literal: true

module ESM
  class UserSteamData < ApplicationRecord
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

    belongs_to :user

    def refresh
      return self if user.steam_uid.blank?

      player_data = ESM::SteamAccount.new(user.steam_uid)
      update(
        username: player_data.username,
        avatar: player_data.avatar,
        profile_url: player_data.profile_url,
        profile_visibility: player_data.profile_visibility,
        profile_created_at: player_data.profile_created_at,
        community_banned: player_data.community_banned?,
        vac_banned: player_data.vac_banned?,
        number_of_vac_bans: player_data.number_of_vac_bans,
        days_since_last_ban: player_data.days_since_last_ban
      )

      self
    end

    # A refresh can happen every 15 minutes
    def needs_refresh?
      ((Time.zone.now - updated_at) / 1.minute) >= 15
    end
  end
end
