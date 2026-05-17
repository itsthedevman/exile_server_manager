# frozen_string_literal: true

#
# Test-mode override of `ESM::SteamAccount#fetch`. Avoids hitting the Steam
# Web API during specs by returning canned responses shaped like real
# `HTTP::Response` (responds to `#status.success?` and `#body.to_s`).
#
# Specs that need to assert ban/banishment behavior or specific summary
# fields should stub the canned helpers (`canned_summary` / `canned_bans`)
# on a per-example basis rather than reaching through here.
#
module ESM
  class SteamAccount
    Response = Struct.new(:body, :status)
    Status = Struct.new(:success?)

    SUMMARY_URL = "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002"
    BANS_URL = "http://api.steampowered.com/ISteamUser/GetPlayerBans/v1"

    private

    #
    # Test override of {ESM::SteamAccount#fetch}. Returns a canned response
    # for known endpoints; other URLs return an empty `{}` body.
    #
    # @param url [String] full Steam API endpoint URL
    #
    # @return [Response] Struct mimicking `HTTP::Response`
    #
    def fetch(url)
      Response.new(canned_body(url), Status.new(true))
    end

    def canned_body(url)
      case url
      when SUMMARY_URL then canned_summary
      when BANS_URL then canned_bans
      else "{}"
      end
    end

    def canned_summary
      {
        response: {
          players: [{
            steamid: @steam_uid,
            communityvisibilitystate: 3,
            profilestate: 1,
            personaname: "TestUser-#{@steam_uid}",
            profileurl: "https://steamcommunity.com/profiles/#{@steam_uid}",
            avatar: "",
            avatarmedium: "",
            avatarfull: "",
            personastate: 0,
            primaryclanid: "0",
            timecreated: 1_577_836_800,
            personastateflags: 0
          }]
        }
      }.to_json
    end

    def canned_bans
      {
        players: [{
          SteamId: @steam_uid,
          CommunityBanned: false,
          VACBanned: false,
          NumberOfVACBans: 0,
          DaysSinceLastBan: 0,
          NumberOfGameBans: 0,
          EconomyBan: "none"
        }]
      }.to_json
    end
  end
end
