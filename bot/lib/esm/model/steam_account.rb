# frozen_string_literal: true

module ESM
  class SteamAccount
    def initialize(steam_uid)
      @steam_uid = steam_uid
    end

    def username
      summary.personaname
    end

    def avatar
      summary.avatarfull
    end

    def profile_url
      summary.profileurl
    end

    def profile_visibility
      {
        1 => "Private",
        2 => "Friends Only",
        3 => "Public"
      }[summary.communityvisibilitystate]
    end

    def profile_created_at
      @profile_created_at ||= lambda do
        # Apparently steam doesn't always give that information
        return if summary.timecreated.nil?

        ::Time.at(summary.timecreated)
      end.call
    end

    def community_banned?
      bans.community_banned
    end

    def vac_banned?
      bans.vac_banned
    end

    def number_of_vac_bans
      bans.number_of_vac_bans
    end

    def days_since_last_ban
      bans.days_since_last_ban
    end

    private

    def query
      {key: ENV["STEAM_TOKEN"], steamids: @steam_uid}
    end

    #                  "steamid" => "76561198037177305",
    # "communityvisibilitystate" => 3,
    #             "profilestate" => 1,
    #              "personaname" => "WolfkillArcadia",
    #               "lastlogoff" => 1570139342,
    #        "commentpermission" => 2,
    #               "profileurl" => "https://steamcommunity.com/id/wolfkillarcadia/",
    #                   "avatar" => "....jpg",
    #             "avatarmedium" => "..._medium.jpg",
    #               "avatarfull" => "..._full.jpg",
    #             "personastate" => 3,
    #            "primaryclanid" => "103582791429521408",
    #              "timecreated" => 1295748172,
    #        "personastateflags" => 0
    def summary
      @summary ||= lambda do
        response = HTTParty.get("http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002", query: query)
        if !response.ok? || response.body.nil? || response["response"].blank?
          ESM.logger.error("#{self.class}##{__method__}") { "Steam summary is nil! UID: #{@steam_uid}\nResponse: #{response}" }
          return
        end

        response["response"]["players"].first.to_ostruct
      end.call
    end

    #          "SteamId" => "76561198037177305",
    #  "CommunityBanned" => false,
    #        "VACBanned" => false,
    #  "NumberOfVACBans" => 0,
    # "DaysSinceLastBan" => 0,
    # "NumberOfGameBans" => 0,
    #       "EconomyBan" => "none"
    def bans
      @bans ||= lambda do
        response = HTTParty.get("http://api.steampowered.com/ISteamUser/GetPlayerBans/v1", query: query)
        if !response.ok? || response.body.nil? || response["players"].blank?
          ESM.logger.error("#{self.class}##{__method__}") { "Steam summary is nil! UID: #{@steam_uid}\nResponse: #{response}" }
          return
        end

        response = response["players"].first

        OpenStruct.new(
          community_banned: response["CommunityBanned"],
          vac_banned: response["VACBanned"],
          number_of_vac_bans: response["NumberOfVACBans"],
          days_since_last_ban: response["DaysSinceLastBan"],
          number_of_game_bans: response["NumberOfGameBans"],
          economy_ban: response["EconomyBan"]
        )
      end.call
    end
  end
end
