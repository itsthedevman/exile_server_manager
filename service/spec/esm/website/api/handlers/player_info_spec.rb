# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::PlayerInfo do
  describe ".call", :requires_connection do
    include_context "connection"

    let(:steam_uid) { Faker::Steam.uid }

    context "when the player has an account on the server" do
      let!(:account) do
        create(
          :exile_account,
          uid: steam_uid,
          locker: 25_000,
          score: 1_500,
          kills: 10,
          deaths: 3
        )
      end

      let!(:player) do
        create(
          :exile_player,
          account_uid: steam_uid,
          money: 5_000,
          damage: 0.25,
          hunger: 80,
          thirst: 60
        )
      end

      it "offloads to a promise resolving to the player's data" do
        promise = described_class.call(server_id: server.id, steam_uid:)
        expect(promise).to be_a(Concurrent::Promise)

        # The handler returns the requested uid's row, proving the steam_uid was
        # forwarded to the query and the seeded data round-tripped through Arma.
        data = promise.value!(10).to_datum
        expect(data.uid).to eq(steam_uid)
        expect(data.name).to eq(account.name)
        expect(data.locker).to eq(25_000)
        expect(data.score).to eq(1_500)
        expect(data.kills).to eq(10)
        expect(data.deaths).to eq(3)
        expect(data.money).to eq(5_000)
      end
    end

    context "when the player has no character on the server" do
      it "resolves to nil" do
        promise = described_class.call(server_id: server.id, steam_uid:)
        expect(promise.value!(10)).to be_nil
      end
    end
  end

  describe ".call" do
    context "when the server does not exist" do
      it "raises ArgumentError without offloading" do
        expect {
          described_class.call(server_id: "does-not-exist", steam_uid: Faker::Steam.uid)
        }.to raise_error(ArgumentError, /Unknown server/)
      end
    end
  end
end
