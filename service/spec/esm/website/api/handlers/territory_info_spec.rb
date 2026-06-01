# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::TerritoryInfo do
  describe ".call", :requires_connection do
    include_context "connection"

    # The player making the request. Whether this uid appears in the territory's
    # owner_uid/build_rights/moderators is exactly what the access scope keys on,
    # so each context below places it in a different column (or none).
    let(:steam_uid) { Faker::Steam.uid }

    # Exile always seeds the owner into both lists when a flag is placed, so a real
    # territory never has an empty member set. Mirror that: an empty
    # build_rights + moderators would make the name-lookup query build `IN ()`,
    # which is a MySQL syntax error rather than a returned row.
    let(:owner_uid) { Faker::Steam.uid }
    let(:moderators) { [owner_uid] }
    let(:build_rights) { [owner_uid] }

    let!(:territory) do
      create(
        :exile_territory,
        owner_uid:,
        moderators:,
        build_rights:,
        server_id: server.id
      )
    end

    def call
      described_class.call(
        server_id: server.id,
        encoded_territory_id: territory.encoded_id,
        steam_uid:
      )
    end

    shared_examples "resolves to the territory" do
      it "resolves to the territory data" do
        promise = call
        expect(promise).to be_a(Concurrent::Promise)

        # Round-trips through Arma: proves the uid was accepted by the access scope
        # and the encoded id decoded/re-encoded symmetrically.
        data = promise.value!(10).to_istruct
        expect(data.id).to eq(territory.encoded_id)
        expect(data.territory_name).to eq(territory.name)
      end
    end

    context "when the requesting player owns the territory" do
      let(:owner_uid) { steam_uid }

      include_examples "resolves to the territory"
    end

    context "when the requesting player has build rights" do
      let(:build_rights) { [steam_uid] }

      include_examples "resolves to the territory"
    end

    context "when the requesting player is a moderator" do
      let(:moderators) { [steam_uid] }

      include_examples "resolves to the territory"
    end

    context "when the requesting player has no rights to the territory" do
      # steam_uid is in none of owner_uid/build_rights/moderators, so the scoped
      # query returns zero rows and the lookup is denied. This is the whole point
      # of threading requesting_uid through: an arbitrary id can't be fetched.
      it "resolves to nil" do
        expect(call.value!(10)).to be_nil
      end
    end

    context "when the territory has no build rights or moderators" do
      # A degenerate row: the owner is absent from both member lists. This can't
      # happen in real Exile (the owner is seeded into both), but the invariant
      # isn't enforced on our side, so the name lookup must not build `IN ()` and
      # crash. It should return the territory with no members. Guards
      # create_name_lookup (see command_player_territories.rs).
      let(:owner_uid) { steam_uid }
      let(:moderators) { [] }
      let(:build_rights) { [] }

      it "resolves to the territory instead of erroring" do
        data = call.value!(10).to_istruct
        expect(data.id).to eq(territory.encoded_id)
        expect(data.build_rights).to be_empty
        expect(data.moderators).to be_empty
      end
    end
  end

  describe ".call" do
    context "when the server does not exist" do
      it "raises ArgumentError without offloading" do
        expect {
          described_class.call(
            server_id: "does-not-exist",
            encoded_territory_id: "anything",
            steam_uid: Faker::Steam.uid
          )
        }.to raise_error(ArgumentError, /Unknown server/)
      end
    end
  end
end
