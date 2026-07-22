# frozen_string_literal: true

describe ESM::Website::Command::SyncOrigin do
  let!(:community) { create(:community) }
  let!(:user) { create(:user) }

  let(:event) { Datum.new(user:, community:, arguments: {}) }

  subject(:origin) { described_class.new(event) }

  describe "#result" do
    it "is nil until the command replies" do
      expect(origin.result).to be_nil
    end

    it "holds whatever the command replied with" do
      origin.reply({uid: user.steam_uid, locker: 25_000})

      expect(origin.result).to eq({uid: user.steam_uid, locker: 25_000})
    end

    # The async path guards against a second reply because the row can only settle once. Here the value is handed
    # back to a caller that is still waiting, so a later reply simply wins.
    it "holds the most recent reply" do
      origin.reply("first")
      origin.reply("second")

      expect(origin.result).to eq("second")
    end
  end

  describe "#reply_error" do
    # There is no row to record a failure on, so the error travels back out to the web request that is still open.
    it "raises rather than recording the error" do
      error = ESM::Exception::CheckFailure.new(key: "command_errors.not_registered", user:, full_username: user.distinct)

      expect { origin.reply_error(error) }.to raise_error(error)
    end
  end

  describe "#current_user" do
    it "is the user the event was built for" do
      expect(origin.current_user).to eq(user)
    end
  end

  describe "#current_community" do
    it "is the community the event was built for" do
      expect(origin.current_community).to eq(community)
    end
  end

  describe "#current_channel" do
    it "is nil because the website has no channel" do
      expect(origin.current_channel).to be_nil
    end
  end

  describe "#from_website?" do
    it "is true for a website origin" do
      expect(origin.from_website?).to be(true)
    end
  end

  describe "#from_discord?" do
    it "is false for a website origin" do
      expect(origin.from_discord?).to be(false)
    end
  end
end
