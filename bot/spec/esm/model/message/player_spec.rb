# frozen_string_literal: true

describe ESM::Message::Player, v2: true do
  describe ".from" do
    let(:user) { {} }

    subject(:player) { described_class.from(user) }

    context "when the input is an instance of ESM::User" do
      let(:user) { ESM::Test.user }

      it "uses the data from the User object" do
        expect(player).to be_instance_of(described_class)

        expect(player.steam_uid).to eq(user.steam_uid)
        expect(player.discord_id).to eq(user.discord_id)
        expect(player.discord_name).to eq(user.discord_username)
        expect(player.discord_mention).to eq(user.discord_mention)
      end
    end

    context "when the input is an instance of ESM::User::Ephemeral" do
      let(:user) { ESM::User::Ephemeral.new(ESM::Test.steam_uid) }

      it "uses the steam_uid for most attributes" do
        expect(player).to be_instance_of(described_class)

        expect(player.steam_uid).to eq(user.steam_uid)
        expect(player.discord_id).to be(nil)
        expect(player.discord_name).to eq(user.steam_uid)
        expect(player.discord_mention).to eq(user.steam_uid)
      end
    end

    context "when the input is an instance of a Hash" do
      let(:user) { {steam_uid: "1", discord_mention: "4", discord_name: "3", discord_id: "2"} }

      it "uses the steam_uid for every attribute" do
        expect(player).to be_instance_of(described_class)

        expect(player.steam_uid).to eq("1")
        expect(player.discord_id).to eq("2")
        expect(player.discord_name).to eq("3")
        expect(player.discord_mention).to eq("4")
      end
    end
  end
end
