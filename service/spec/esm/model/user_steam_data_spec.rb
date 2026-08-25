# frozen_string_literal: true

RSpec.describe ESM::UserSteamData do
  describe ".from_steam_uid" do
    subject(:steam_data) { described_class.from_steam_uid(steam_uid) }

    # A fresh UID per example keeps one example's cache entry out of the next one's way.
    let(:steam_uid) { Faker::Steam.uid }

    it "returns a row that is never written back" do
      expect(steam_data).to be_a(described_class)
      expect(steam_data).not_to be_persisted
      expect(steam_data).to be_readonly
    end

    it "projects the same shape as a persisted row" do
      expect(steam_data.to_h.keys).to match_array(described_class.new.to_h.keys)
    end

    # There is no row to write and no updated_at to measure against, so #refresh has to bow out rather than reach
    # for a user that does not exist.
    it "treats #refresh as a no-op" do
      expect(steam_data.refresh).to be(steam_data)
    end

    # Nothing backs an unregistered UID, so without the cache every lookup would be another round trip to Steam.
    it "asks Steam once per refresh interval" do
      account = instance_double(ESM::SteamAccount, valid?: true, to_h: {username: "Dave"})
      expect(ESM::SteamAccount).to receive(:new).once.and_return(account)

      expect(described_class.from_steam_uid(steam_uid).username).to eq("Dave")
      expect(described_class.from_steam_uid(steam_uid).username).to eq("Dave")
    end

    # A Steam outage must not pin an empty answer in place for the rest of the interval.
    it "does not cache a lookup Steam could not answer" do
      account = instance_double(ESM::SteamAccount, valid?: false)
      expect(ESM::SteamAccount).to receive(:new).twice.and_return(account)

      expect(described_class.from_steam_uid(steam_uid).username).to be_nil
      expect(described_class.from_steam_uid(steam_uid).username).to be_nil
    end
  end
end
