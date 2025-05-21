# frozen_string_literal: true

module ESM
  class SteamAccount
    EMPTY_STRUCT = OpenStruct.new

    def initialize(steam_uid)
      @steam_uid = steam_uid
    end

    def valid?
      summary.is_a?(Data)
    end

    def username
      summary.persona_name
    end

    def avatar
      summary.avatar_full
    end

    delegate :profile_url, to: :summary

    def profile_visibility
      {
        1 => "Private",
        2 => "Friends Only",
        3 => "Public"
      }[summary.community_visibility_state]
    end

    def profile_created_at
      @profile_created_at ||= lambda do
        # Apparently steam doesn't always give that information
        return if summary.time_created.nil?

        ::Time.zone.at(summary.time_created)
      end.call
    end

    def community_banned?
      bans.community_banned
    end

    def vac_banned?
      bans.vac_banned
    end

    delegate :number_of_vac_bans, :days_since_last_ban, to: :bans

    private

    def query
      {key: ENV["STEAM_TOKEN"], steamids: @steam_uid}
    end

    def summary
      @summary ||= lambda do
        response = HTTParty.get(
          "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002",
          query:
        )

        if !response.ok? || response.body.nil? || response["response"].blank?
          error!("Steam summary is nil! UID: #{@steam_uid}\nResponse: #{response}")
          return EMPTY_STRUCT
        end

        data = response.dig("response", "players")&.first
        if data.blank?
          error!("Steam players response is blank! UID: #{@steam_uid}\nResponse: #{response}")
          return EMPTY_STRUCT
        end

        {
          steam_id: data["steamid"],
          community_visibility_state: data["communityvisibilitystate"],
          profile_state: data["profilestate"],
          persona_name: data["personaname"],
          last_logoff: data["lastlogoff"],
          comment_permission: data["commentpermission"],
          profile_url: data["profileurl"],
          avatar: data["avatar"],
          avatar_medium: data["avatarmedium"],
          avatar_full: data["avatarfull"],
          persona_state: data["personastate"],
          primary_clan_id: data["primaryclanid"],
          time_created: data["timecreated"],
          persona_state_flags: data["personastateflags"]
        }.to_istruct
      end.call
    end

    #          "SteamId" => "76561234567890123",
    #  "CommunityBanned" => false,
    #        "VACBanned" => false,
    #  "NumberOfVACBans" => 0,
    # "DaysSinceLastBan" => 0,
    # "NumberOfGameBans" => 0,
    #       "EconomyBan" => "none"
    def bans
      @bans ||= lambda do
        response = HTTParty.get("http://api.steampowered.com/ISteamUser/GetPlayerBans/v1", query:)
        if !response.ok? || response.body.nil? || response["players"].blank?
          error!("Steam bans is nil! UID: #{@steam_uid}\nResponse: #{response}")
          return EMPTY_STRUCT
        end

        data = response["players"].first
        {
          community_banned: data["CommunityBanned"],
          vac_banned: data["VACBanned"],
          number_of_vac_bans: data["NumberOfVACBans"],
          days_since_last_ban: data["DaysSinceLastBan"],
          number_of_game_bans: data["NumberOfGameBans"],
          economy_ban: data["EconomyBan"]
        }.to_istruct
      end.call
    end
  end
end
