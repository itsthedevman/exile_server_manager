# frozen_string_literal: true

require "rails_helper"

RSpec.describe OmniAuth::Strategies::Steam do
  include Rack::Test::Methods

  let(:app) do
    Rack::Builder.new do
      use OmniAuth::Test::PhonySession
      use OmniAuth::Builder do
        provider :steam, "test_api_key"
      end

      run ->(env) { [404, {"Content-Type" => "text/plain"}, [env.key?("omniauth.auth").to_s]] }
    end.to_app
  end

  let(:steam_uid) { "76560000000000000" }
  let(:api_response) do
    {
      "response" => {
        "players" => [
          {
            "steamid" => steam_uid,
            "personaname" => "TestPlayer",
            "realname" => "Test User",
            "loccityid" => "1234",
            "locstatecode" => "CA",
            "loccountrycode" => "US",
            "avatarmedium" => "https://example.com/avatar.jpg",
            "profileurl" => "https://steamcommunity.com/id/testplayer"
          }
        ]
      }
    }.to_json
  end

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:steam] = nil
  end

  describe "configuration" do
    subject(:strategy) { OmniAuth::Strategies::Steam.new(app, "test_api_key") }

    it "has the correct name" do
      expect(strategy.options.name).to eq("steam")
    end

    it "has the correct identifier" do
      expect(strategy.options.identifier).to eq("http://steamcommunity.com/openid")
    end

    it "accepts an api_key" do
      expect(strategy.options.api_key).to eq("test_api_key")
    end
  end

  describe "integration tests" do
    # Note: Full authentication flow requires OpenID interaction with Steam
    # For integration testing, use the actual OAuth flow in a feature spec

    it "can be mocked for testing purposes" do
      OmniAuth.config.add_mock(:steam, {
        uid: steam_uid,
        info: {
          nickname: "TestPlayer",
          name: "Test User"
        }
      })

      expect(OmniAuth.config.mock_auth[:steam]).to be_present
      expect(OmniAuth.config.mock_auth[:steam][:uid]).to eq(steam_uid)
    end
  end

  describe "private methods" do
    subject(:strategy) { OmniAuth::Strategies::Steam.new(app, "test_api_key") }

    describe "#fetch_player_info" do
      before do
        allow(strategy).to receive(:steam_id).and_return(steam_uid)
        stub_request(:get, %r{api.steampowered.com/ISteamUser/GetPlayerSummaries})
          .to_return(status: 200, body: api_response)
      end

      it "fetches player information from Steam API" do
        info = strategy.send(:fetch_player_info)

        expect(info["response"]["players"]).to be_an(Array)
        expect(info["response"]["players"].first["steamid"]).to eq(steam_uid)
        expect(info["response"]["players"].first["personaname"]).to eq("TestPlayer")
      end

      context "when API key is not provided" do
        subject(:strategy) { OmniAuth::Strategies::Steam.new(app, nil) }

        it "returns an empty hash" do
          expect(strategy.send(:fetch_player_info)).to eq({})
        end
      end

      context "when API returns invalid JSON" do
        before do
          stub_request(:get, %r{api.steampowered.com/ISteamUser/GetPlayerSummaries})
            .to_return(status: 200, body: "invalid json")
        end

        it "logs error and returns empty hash" do
          expect(Rails.logger).to receive(:error).with(/Failed to parse Steam API response/)
          expect(strategy.send(:fetch_player_info)).to eq({})
        end
      end

      context "when API request fails" do
        before do
          stub_request(:get, %r{api.steampowered.com/ISteamUser/GetPlayerSummaries})
            .to_raise(StandardError.new("Connection failed"))
        end

        it "raises the error" do
          expect { strategy.send(:fetch_player_info) }.to raise_error(StandardError, "Connection failed")
        end
      end
    end

    describe "#player" do
      let(:raw_info) do
        {
          "response" => {
            "players" => [
              {"steamid" => steam_uid, "personaname" => "TestPlayer"}
            ]
          }
        }
      end

      before do
        allow(strategy).to receive(:raw_info).and_return(raw_info)
      end

      it "extracts the first player from the response" do
        player = strategy.send(:player)

        expect(player["steamid"]).to eq(steam_uid)
        expect(player["personaname"]).to eq("TestPlayer")
      end

      context "when response has no players" do
        let(:raw_info) { {"response" => {}} }

        it "returns nil" do
          expect(strategy.send(:player)).to be_nil
        end
      end

      context "when response is empty" do
        let(:raw_info) { {} }

        it "returns nil" do
          expect(strategy.send(:player)).to be_nil
        end
      end
    end

    describe "#build_location" do
      before do
        allow(strategy).to receive(:player).and_return(player_data)
      end

      context "with all location parts" do
        let(:player_data) do
          {
            "loccityid" => "1234",
            "locstatecode" => "CA",
            "loccountrycode" => "US"
          }
        end

        it "joins all parts with commas" do
          expect(strategy.send(:build_location)).to eq("1234, CA, US")
        end
      end

      context "with some nil parts" do
        let(:player_data) do
          {
            "loccityid" => nil,
            "locstatecode" => "CA",
            "loccountrycode" => "US"
          }
        end

        it "only includes non-nil parts" do
          expect(strategy.send(:build_location)).to eq("CA, US")
        end
      end

      context "with all nil parts" do
        let(:player_data) do
          {
            "loccityid" => nil,
            "locstatecode" => nil,
            "loccountrycode" => nil
          }
        end

        it "returns empty string" do
          expect(strategy.send(:build_location)).to eq("")
        end
      end
    end

    describe "#extract_steam_id_from_response" do
      let(:openid_response) do
        double(
          display_identifier: "https://steamcommunity.com/openid/id/#{steam_uid}",
          endpoint: double(claimed_id: "https://steamcommunity.com/openid/id/#{steam_uid}")
        )
      end

      before do
        allow(strategy).to receive(:openid_response).and_return(openid_response)
      end

      it "extracts the Steam ID from the OpenID response" do
        expect(strategy.send(:extract_steam_id_from_response)).to eq(steam_uid)
      end

      context "when claimed ID doesn't match expected format" do
        let(:openid_response) do
          double(
            display_identifier: "https://steamcommunity.com/openid/id/#{steam_uid}",
            endpoint: double(claimed_id: "https://malicious.com/openid/id/#{steam_uid}")
          )
        end

        it "raises an error" do
          expect { strategy.send(:extract_steam_id_from_response) }
            .to raise_error("Steam Claimed ID mismatch!")
        end
      end
    end

    describe "#player_profile_uri" do
      before do
        allow(strategy).to receive(:steam_id).and_return(steam_uid)
      end

      it "constructs the correct Steam API URL" do
        uri = strategy.send(:player_profile_uri)

        expect(uri.to_s).to include("api.steampowered.com/ISteamUser/GetPlayerSummaries")
        expect(uri.to_s).to include("key=test_api_key")
        expect(uri.to_s).to include("steamids=#{steam_uid}")
      end
    end

    describe "#friend_list_url" do
      before do
        allow(strategy).to receive(:steam_id).and_return(steam_uid)
      end

      it "constructs the correct Steam API URL" do
        uri = strategy.send(:friend_list_url)

        expect(uri.to_s).to include("api.steampowered.com/ISteamUser/GetFriendList")
        expect(uri.to_s).to include("key=test_api_key")
        expect(uri.to_s).to include("steamid=#{steam_uid}")
        expect(uri.to_s).to include("relationship=friend")
      end
    end
  end
end
