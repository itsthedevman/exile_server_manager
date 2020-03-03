# frozen_string_literal: true

module ESM
  module Service
    class Steam
      # Wraps SteamWebApi gem
      # @see https://github.com/Olgagr/steam-web-api
      def initialize(steam_uid)
        @player = SteamWebApi::Player.new(steam_uid)
      end

      #          "SteamId" => "76561198037177305",
      #  "CommunityBanned" => false,
      #        "VACBanned" => false,
      #  "NumberOfVACBans" => 0,
      # "DaysSinceLastBan" => 0,
      # "NumberOfGameBans" => 0,
      #       "EconomyBan" => "none"
      def player_bans
        return @player_bans if @player_bans

        data = @player.bans
        @player_bans ||= data.bans.to_ostruct if data.success
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
      def player_info
        return @player_info if @player_info

        data = @player.summary
        @player_info ||= data.profile.to_ostruct if data.success
      end

      def profile_visibility
        player_info if @player_info.nil?

        {
          1 => "Private",
          2 => "Friends Only",
          3 => "Public"
        }[@player_info.communityvisibilitystate]
      end

      def profile_created_at
        player_info if @player_info.nil?

        # Apparently steam doesn't always give that information
        return if @player_info.timecreated.nil?

        @profile_created_at ||= ::Time.at(@player_info.timecreated)
      end
    end
  end
end
