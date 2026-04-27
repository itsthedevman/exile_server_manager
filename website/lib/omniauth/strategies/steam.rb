# frozen_string_literal: true

# Vendored OmniAuth Steam strategy
#
# The original omniauth-steam gem (v1.0.6) uses multi_json which has compatibility
# issues with Ruby 3.3.10+ causing "nil is not a class/module" errors during
# authentication callbacks. This vendored version uses Ruby's standard JSON library.
#
# Original gem: https://github.com/reu/omniauth-steam

module OmniAuth
  module Strategies
    class Steam < OmniAuth::Strategies::OpenID
      # =============================================================================
      # CONFIGURATION
      # =============================================================================

      args :api_key

      option :api_key, nil
      option :name, "steam"
      option :identifier, "http://steamcommunity.com/openid"

      # =============================================================================
      # OMNIAUTH INTERFACE
      # =============================================================================

      uid { steam_id }

      info do
        if player
          {
            "nickname" => player["personaname"],
            "name" => player["realname"],
            "location" => build_location,
            "image" => player["avatarmedium"],
            "urls" => {
              "Profile" => player["profileurl"],
              "FriendList" => friend_list_url
            }
          }
        else
          {}
        end
      rescue JSON::ParserError => e
        fail!(:steam_error, e)
        {}
      end

      extra do
        {"raw_info" => player}
      rescue JSON::ParserError => e
        fail!(:steam_error, e)
        {}
      end

      # =============================================================================
      # PRIVATE METHODS
      # =============================================================================

      private

      def steam_id
        @steam_id ||= extract_steam_id_from_response
      end

      def player
        @player ||= raw_info.dig("response", "players")&.first
      end

      def raw_info
        @raw_info ||= fetch_player_info
      end

      def fetch_player_info
        return {} unless options.api_key

        response = Net::HTTP.get(player_profile_uri)
        JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.error("[Steam] Failed to parse Steam API response: #{e.message}")
        {}
      end

      def extract_steam_id_from_response
        claimed_id = openid_response.display_identifier.split("/").last
        expected_uri = %r{\Ahttps?://steamcommunity\.com/openid/id/#{claimed_id}\Z}

        if !expected_uri.match?(openid_response.endpoint.claimed_id)
          raise "Steam Claimed ID mismatch!"
        end

        claimed_id
      end

      def build_location
        parts = [
          player["loccityid"],
          player["locstatecode"],
          player["loccountrycode"]
        ].compact

        parts.join(", ")
      end

      def player_profile_uri
        URI.parse(
          "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/" \
          "?key=#{options.api_key}&steamids=#{steam_id}"
        )
      end

      def friend_list_url
        URI.parse(
          "https://api.steampowered.com/ISteamUser/GetFriendList/v0001/" \
          "?key=#{options.api_key}&steamid=#{steam_id}&relationship=friend"
        )
      end
    end
  end
end
