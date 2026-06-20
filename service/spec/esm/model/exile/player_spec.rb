# frozen_string_literal: true

describe ESM::Exile::Player do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, :v2, community_id: community.id) }

  let(:player_data) do
    {
      uid: Faker::Steam.uid,
      name: "Wolfkill",
      locker: 5_000,
      score: 1_200,
      kills: 10,
      deaths: 5,
      first_connect_at: "2026-01-01 00:00:00",
      last_disconnect_at: "2026-06-01 00:00:00",
      total_connections: 42,
      money: 300,
      damage: 0.25,
      hunger: 80.5,
      thirst: 60.0,
      territories: []
    }
  end

  subject(:player) { described_class.new(server:, player: player_data) }

  describe "scalar accessors" do
    it "returns the underlying values" do
      expect(player.name).to eq("Wolfkill")
      expect(player.uid).to eq(player_data[:uid])
      expect(player.money).to eq(300)
      expect(player.locker).to eq(5_000)
      expect(player.score).to eq(1_200)
      expect(player.kills).to eq(10)
      expect(player.deaths).to eq(5)
      expect(player.first_connect_at).to eq("2026-01-01 00:00:00")
      expect(player.last_disconnect_at).to eq("2026-06-01 00:00:00")
      expect(player.total_connections).to eq(42)
    end
  end

  describe "#respect" do
    it "aliases #score (the database column)" do
      expect(player.respect).to eq(player.score)
      expect(player.respect).to eq(1_200)
    end
  end

  describe "#alive?" do
    it "is alive when damage is below 1" do
      expect(player.alive?).to be(true)
    end

    it "is not alive when the character is dead (damage == 1)" do
      player_data[:damage] = 1
      expect(player.alive?).to be(false)
    end

    it "is not alive when there is no character (damage nil)" do
      player_data[:damage] = nil
      expect(player.alive?).to be(false)
    end
  end

  describe "#health" do
    it "converts damage into a health percentage" do
      expect(player.health).to eq(75.0)
    end

    it "is nil when not alive" do
      player_data[:damage] = 1
      expect(player.health).to be_nil
    end
  end

  describe "#hunger / #thirst" do
    it "returns the values" do
      expect(player.hunger).to eq(80.5)
      expect(player.thirst).to eq(60.0)
    end
  end

  describe "#kd_ratio" do
    it "divides kills by deaths" do
      expect(player.kd_ratio).to eq(2.0)
    end

    it "is 0 when there are no deaths" do
      player_data[:deaths] = 0
      expect(player.kd_ratio).to eq(0)
    end
  end

  describe "normalization of a dead or absent character" do
    it "defaults the missing survival and currency fields" do
      player_data.merge!(
        damage: nil, hunger: nil, thirst: nil,
        kills: nil, deaths: nil, money: nil, territories: nil
      )

      expect(player.alive?).to be(false)
      expect(player.hunger).to eq(0)
      expect(player.thirst).to eq(0)
      expect(player.kills).to eq(0)
      expect(player.deaths).to eq(0)
      expect(player.money).to eq(0)
      expect(player.territories).to eq([])
    end
  end

  describe "#territories" do
    before do
      player_data[:territories] = [
        {id: "2", name: "Zulu Base", flag_stolen: false},
        {id: "1", name: "Alpha Base", flag_stolen: false}
      ]
    end

    it "builds Exile::Territory objects sorted by name" do
      expect(player.territories).to all(be_a(ESM::Exile::Territory))
      expect(player.territories.map(&:name)).to eq(["Alpha Base", "Zulu Base"])
    end
  end

  describe ".from_v1" do
    # V1 servers send territories as a name => id map. The instance shape is the
    # same array of Territory objects regardless of how it arrived.
    let(:v1_server) { create(:server, community_id: community.id) }

    it "parses a JSON-string territories map into sorted Territory objects" do
      data = player_data.merge(territories: {"Zulu" => "z1", "Alpha" => "a1"}.to_json)
      player = described_class.from_v1(server: v1_server, player: data)

      expect(player.territories).to all(be_a(ESM::Exile::Territory))
      expect(player.territories.map { |territory| territory.name.to_s }).to eq(["Alpha", "Zulu"])
    end

    it "parses an already-parsed hash territories map" do
      data = player_data.merge(territories: {"Zulu" => "z1", "Alpha" => "a1"})
      player = described_class.from_v1(server: v1_server, player: data)

      expect(player.territories.map { |territory| territory.name.to_s }).to eq(["Alpha", "Zulu"])
    end

    it "handles a player with no territories" do
      data = player_data.merge(territories: nil)
      player = described_class.from_v1(server: v1_server, player: data)

      expect(player.territories).to eq([])
    end
  end
end
