# frozen_string_literal: true

RSpec.describe ESM::ServerReward do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, :with_reward, community: community) }

  describe ".default" do
    it "returns the reward the default reward_id" do
      default_reward = server.server_rewards.default.first

      expect(default_reward).to be_present
      expect(default_reward.reward_id).to eq("default")
    end

    it "does not return named rewards" do
      named_reward = create(:server_reward, server: server, reward_id: "daily_bonus")

      expect(described_class.where(server: server).default).not_to eq(named_reward)
    end
  end

  describe "default attribute values" do
    let(:reward) { create(:server_reward, server: server, reward_id: "foo") }

    it "defaults reward_items to empty hash" do
      expect(reward.reward_items).to eq({})
    end

    it "defaults reward_vehicles to empty array" do
      expect(reward.reward_vehicles).to eq([])
    end

    it "defaults poptabs to 0" do
      expect(reward.player_poptabs).to eq(0)
      expect(reward.locker_poptabs).to eq(0)
    end

    it "defaults respect to 0" do
      expect(reward.respect).to eq(0)
    end
  end

  describe "JSON attributes" do
    let(:reward) { create(:server_reward, server: server, reward_id: "foo") }

    describe "reward_items" do
      it "stores item data as JSON" do
        items = {"Exile_Item_Knife" => 1, "Exile_Item_PlasticBottleFreshWater" => 5}
        reward.update!(reward_items: items)
        reward.reload

        expect(reward.reward_items).to eq(items)
      end
    end

    describe "reward_vehicles" do
      it "stores vehicle data as JSON array" do
        vehicles = [
          {"class_name" => "Exile_Car_Offroad_Red", "spawn_location" => "nearby"},
          {"class_name" => "Exile_Chopper_Huey_Green", "spawn_location" => "virtual_garage"}
        ]
        reward.update!(reward_vehicles: vehicles)
        reward.reload

        expect(reward.reward_vehicles).to eq(vehicles)
      end
    end
  end

  describe "associations" do
    it "belongs to a server" do
      reward = create(:server_reward, server: server, reward_id: "foo")
      expect(reward.server).to eq(server)
    end
  end

  describe "cooldown attributes" do
    let(:reward) { create(:server_reward, server: server, reward_id: "foo") }

    it "stores cooldown configuration" do
      reward.update!(cooldown_quantity: 24, cooldown_type: "hours")
      reward.reload

      expect(reward.cooldown_quantity).to eq(24)
      expect(reward.cooldown_type).to eq("hours")
    end
  end

  describe "#cooldown_time" do
    let(:reward) { create(:server_reward, server: server, reward_id: "foo") }

    it "recomposes the two columns into a duration" do
      reward.update!(cooldown_quantity: 24, cooldown_type: "hours")

      expect(reward.cooldown_time).to eq(24.hours)
    end

    it "handles every unit an owner can configure" do
      reward.update!(cooldown_quantity: 30, cooldown_type: "seconds")
      expect(reward.cooldown_time).to eq(30.seconds)

      reward.update!(cooldown_quantity: 2, cooldown_type: "days")
      expect(reward.cooldown_time).to eq(2.days)
    end

    context "when the owner never configured a cooldown" do
      it "returns nil when neither column is set" do
        expect(reward.cooldown_time).to be_nil
      end

      it "returns nil when the quantity is missing" do
        reward.update!(cooldown_quantity: nil, cooldown_type: "hours")

        expect(reward.cooldown_time).to be_nil
      end

      it "returns nil when the type is missing" do
        reward.update!(cooldown_quantity: 24, cooldown_type: nil)

        expect(reward.cooldown_time).to be_nil
      end
    end
  end
end
