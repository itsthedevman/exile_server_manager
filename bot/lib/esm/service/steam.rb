# frozen_string_literal: true

module ESM
  module Service
    class Steam
      # Wraps SteamWebApi gem
      # @see https://github.com/Olgagr/steam-web-api
      def initialize(steam_uid)
        @player = SteamWebApi::Player.new(steam_uid)
      end

      def username
        player_info.personaname
      end

      def avatar
        player_info.avatarfull
      end

      def profile_url
        player_info.profileurl
      end

      def profile_visibility
        {
          1 => "Private",
          2 => "Friends Only",
          3 => "Public"
        }[player_info.communityvisibilitystate]
      end

      def profile_created_at
        @profile_created_at ||= lambda do
          # Apparently steam doesn't always give that information
          return if player_info.timecreated.nil?

          ::Time.at(player_info.timecreated)
        end.call
      end

      def community_banned?
        player_bans.CommunityBanned
      end

      def vac_banned?
        player_bans.VACBanned
      end

      def number_of_vac_bans
        player_bans.NumberOfVACBans
      end

      def days_since_last_ban
        player_bans.DaysSinceLastBan
      end

      private

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
        @player_info ||= lambda do
          data = @player.summary
          data.profile.to_ostruct if data.success
        end.call
      end
    end
  end
end
