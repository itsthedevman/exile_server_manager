# frozen_string_literal: true

RSpec.describe ESM::ServerRewardClaim do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let!(:user) { create(:user) }

  def create_claim(**attributes)
    described_class.create!(
      server_id: server.id,
      user_id: user.id,
      player_poptabs: 25,
      state: :waiting,
      **attributes
    )
  end

  describe "#interrupt!" do
    it "stops the claim and says why" do
      claim = create_claim(state: :in_flight)

      claim.interrupt!("the server never answered")

      expect(claim).to be_failed
      expect(claim.state_details[:failures]).to eq(
        [{bucket: "delivery", name: "Delivery", reason: "the server never answered"}]
      )
    end

    # The leftovers the claim holds are the ones that attempt reported on, so their reasons still describe them
    it "keeps what the last attempt already reported" do
      claim = create_claim(
        state: :in_flight,
        state_details: {failures: [{bucket: "vehicles", name: "Hatchback", reason: "that territory's garage is full"}]}
      )

      claim.interrupt!("the server never answered")

      expect(claim.state_details[:failures].size).to eq(2)
      expect(claim.state_details[:failures].first[:name]).to eq("Hatchback")
      expect(claim.state_details[:failures].last[:reason]).to eq("the server never answered")
    end
  end

  describe ".settle_interrupted_deliveries!" do
    it "stops a delivery that was running when the process went down" do
      claim = create_claim(state: :in_flight)

      described_class.settle_interrupted_deliveries!

      claim.reload
      expect(claim).to be_failed
      expect(claim.state_details[:failures].first[:reason]).to match("restarted")
    end

    it "leaves claims nobody was delivering alone" do
      waiting = create_claim(state: :waiting)
      failed = create_claim(state: :failed, user_id: create(:user).id)

      described_class.settle_interrupted_deliveries!

      expect(waiting.reload).to be_waiting
      expect(failed.reload.state_details).to eq({})
    end
  end
end
