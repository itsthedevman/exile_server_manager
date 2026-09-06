# frozen_string_literal: true

RSpec.describe RewardsHelper, type: :helper do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:package) { server.server_rewards.default.first }

  before { allow(helper).to receive(:current_user).and_return(user) }

  describe "#reward_default_package_for" do
    before do
      package.update!(player_poptabs: 500, reward_items: {}, reward_vehicles: [])
    end

    it "offers the default package" do
      expect(helper.reward_default_package_for(server)).to eq(package)
    end

    # Every other package is claimed by typing its ID. Putting them all on the page would defeat an owner running one
    # as a coupon, since nothing else stops a player taking a package the moment they can see its ID.
    it "never offers a named package" do
      ESM::ServerReward.create!(server_id: server.id, reward_id: "secret", player_poptabs: 100)

      expect(helper.reward_default_package_for(server)).to eq(package)
    end

    # An empty package is an admin midway through configuring one. The command refuses it, so offering it would only
    # promise something that cannot be delivered.
    it "offers nothing when the default has nothing configured" do
      package.update!(player_poptabs: 0, locker_poptabs: 0, respect: 0, reward_items: {}, reward_vehicles: [])

      expect(helper.reward_default_package_for(server)).to be_nil
    end

    it "offers nothing when the default is disabled" do
      package.update!(enabled: false)

      expect(helper.reward_default_package_for(server)).to be_nil
    end
  end

  describe "#reward_claim_for" do
    it "finds what this player is owed on this server" do
      claim = ESM::ServerRewardClaim.create!(server_id: server.id, user_id: user.id, player_poptabs: 25)

      expect(helper.reward_claim_for(server)).to eq(claim)
    end

    # A claim is per server, so one waiting elsewhere must not block or appear on this server's dashboard
    it "ignores a claim on another server" do
      other_server = create(:server)
      ESM::ServerRewardClaim.create!(server_id: other_server.id, user_id: user.id, player_poptabs: 25)

      expect(helper.reward_claim_for(server)).to be_nil
    end
  end

  describe "#reward_availability_label" do
    it "is available when nothing is standing in the way" do
      expect(helper.reward_availability_label(server, package)).to eq("Available")
      expect(helper.reward_package_available?(server, package)).to be(true)
    end

    it "counts down while the package's own cooldown runs" do
      create(
        :cooldown, :active,
        command_name: "reward",
        scope_key: package.reward_id,
        steam_uid: user.steam_uid,
        community_id: server.community_id,
        server_id: server.id
      )

      expect(helper.reward_availability_label(server, package)).to start_with("Available in")
      expect(helper.reward_package_available?(server, package)).to be(false)
    end

    # A usage-count cooldown has no clock, so rendering expires_at would show a date nobody is waiting on
    it "says the uses are spent rather than showing a date" do
      create(
        :cooldown,
        command_name: "reward",
        scope_key: package.reward_id,
        steam_uid: user.steam_uid,
        community_id: server.community_id,
        server_id: server.id,
        cooldown_type: "times",
        cooldown_quantity: 1,
        cooldown_amount: 1
      )

      expect(helper.reward_availability_label(server, package)).to eq("No uses left")
    end

    # scope_key is what keeps packages independent. A cooldown on one must not close another.
    it "ignores a cooldown belonging to a different package" do
      create(
        :cooldown, :active,
        command_name: "reward",
        scope_key: "some_other_package",
        steam_uid: user.steam_uid,
        community_id: server.community_id,
        server_id: server.id
      )

      expect(helper.reward_availability_label(server, package)).to eq("Available")
    end
  end

  describe "#reward_receipt_lines" do
    before do
      package.update!(
        player_poptabs: 5_000,
        locker_poptabs: 0,
        respect: 100,
        reward_items: {Exile_Item_Knife: 1},
        reward_vehicles: [{class_name: "Exile_Car_Hatchback_Rusty1", spawn_location: "nearby"}]
      )
    end

    it "itemises everything the package holds, and nothing it does not" do
      lines = helper.reward_receipt_lines(package.contents).map { |line| [line.label, line.value] }

      expect(lines).to eq(
        [
          ["Poptabs", "5,000"],
          ["Respect", "100"],
          ["Knife", "x1"],
          ["Hatchback", "spawns next to you"]
        ]
      )
    end

    # The delivery form under it names every vehicle already, since it has to say which pin belongs to which
    it "leaves the vehicles out when asked to" do
      lines = helper.reward_receipt_lines(package.contents, include_vehicles: false)

      expect(lines.map(&:label)).to eq(["Poptabs", "Respect", "Knife"])
    end
  end

  describe "#reward_claim_failures" do
    let(:claim) do
      ESM::ServerRewardClaim.create!(
        server_id: server.id,
        user_id: user.id,
        state_details: {failures: [{bucket: "vehicles", name: "Hatchback", reason: "No room to spawn here"}]}
      )
    end

    it "names what could not be delivered and why" do
      expect(helper.reward_claim_failures(claim)).to eq(["Hatchback: No room to spawn here"])
    end

    it "has nothing to say about a claim that has not been attempted" do
      expect(helper.reward_claim_failures(ESM::ServerRewardClaim.new)).to be_empty
    end
  end
end
