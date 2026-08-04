# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::SyncCommand do
  describe ".call", :requires_connection do
    include_context "connection"

    # The handler runs the named command as this user, so the command reads its own steam_uid off them rather than
    # trusting a uid the caller named.
    let(:steam_uid) { user.steam_uid }

    def call(command_name, **arguments)
      described_class.call(
        command_name:,
        user_id: user.id,
        community_id: community.id,
        arguments: {server_id: server.server_id, **arguments}
      )
    end

    context "when running me" do
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
        promise = call("me")
        expect(promise).to be_a(Concurrent::Promise)

        # The handler returns the calling user's row, proving the user_id was resolved into a player and the seeded
        # data round-tripped through Arma.
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

    context "when running me and the player has no character on the server" do
      it "resolves to nil" do
        expect(call("me").value!(10)).to be_nil
      end
    end

    context "when running territory" do
      let(:territory_owner) { steam_uid }

      it "forwards the command's own arguments and resolves to the territory" do
        data = call("territory", territory_id: territory.encoded_id).value!(10).to_datum

        expect(data.territory_name).to eq(territory.name)
        expect(data.owner_uid).to eq(steam_uid)
      end
    end

    # The web path replies with nothing rather than raising, because the page renders its own unavailable state and
    # would only have to translate an error back into that.
    context "when the player has no rights to the requested territory" do
      it "resolves to nil" do
        expect(call("territory", territory_id: territory.encoded_id).value!(10)).to be_nil
      end
    end

    # A command that does raise fails as a command rather than as a handler crash, so the RPC answers with a failure
    # the website degrades from instead of returning a bad value.
    context "when the command itself rejects the request" do
      it "resolves with the command's error" do
        promise = call("territory", territory_id: "nonexistent")

        expect { promise.value!(10) }.to raise_error(ESM::Exception::ExtensionError)
      end
    end
  end

  describe ".call" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community_id: community.id) }
    let!(:user) { create(:user) }

    context "when no command answers to that name" do
      it "raises ArgumentError without offloading" do
        expect {
          described_class.call(
            command_name: "not_a_command",
            user_id: user.id,
            community_id: community.id,
            arguments: {server_id: server.server_id}
          )
        }.to raise_error(ArgumentError, /Unknown command/)
      end
    end

    context "when the user_id belongs to nobody registered with ESM" do
      it "raises ArgumentError without offloading" do
        expect {
          described_class.call(
            command_name: "me",
            user_id: -1,
            community_id: community.id,
            arguments: {server_id: server.server_id}
          )
        }.to raise_error(ArgumentError, /Unknown player/)
      end
    end

    context "when the community_id belongs to no community" do
      it "raises ArgumentError without offloading" do
        expect {
          described_class.call(
            command_name: "me",
            user_id: user.id,
            community_id: -1,
            arguments: {server_id: server.server_id}
          )
        }.to raise_error(ArgumentError, /Unknown community/)
      end
    end
  end
end
