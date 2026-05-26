# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::PlayerInfo do
  describe ".call" do
    let(:community) { create(:community) }
    let(:server) { create(:server, community_id: community.id) }
    let(:steam_uid) { Faker::Steam.uid }
    let(:player_data) { {"uid" => steam_uid, "name" => "Player", "locker" => 1000} }

    it "offloads to a promise resolving to the player's data" do
      allow_any_instance_of(ESM::Server)
        .to receive(:query_exile_database!)
        .and_return([player_data])

      promise = described_class.call(server_id: server.public_id, steam_uid: steam_uid)

      expect(promise).to be_a(Concurrent::Promise)
      expect(promise.value!(2)).to eq(player_data)
    end

    it "queries player_info with the given steam_uid" do
      captured = nil
      allow_any_instance_of(ESM::Server).to receive(:query_exile_database!) do |_instance, name, **kwargs|
        captured = [name, kwargs]
        [player_data]
      end

      described_class.call(server_id: server.public_id, steam_uid: steam_uid).value!(2)

      expect(captured).to eq(["player_info", {uid: steam_uid}])
    end

    it "resolves to nil when the player has no character on the server" do
      allow_any_instance_of(ESM::Server)
        .to receive(:query_exile_database!)
        .and_return([])

      promise = described_class.call(server_id: server.public_id, steam_uid: steam_uid)

      expect(promise.value!(2)).to be_nil
    end

    context "when the server does not exist" do
      it "raises ArgumentError without offloading" do
        expect {
          described_class.call(server_id: "does-not-exist", steam_uid: steam_uid)
        }.to raise_error(ArgumentError, /Unknown server/)
      end
    end
  end
end
