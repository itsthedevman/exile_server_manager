# frozen_string_literal: true

describe ESM::ServerReward do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:rewards) { create(:server_reward, player_poptabs: 5000, locker_poptabs: 2500, respect: 7500, server_id: server.id) }

  it "should be valid" do
    expect(rewards.reward_items).not_to be_blank
    expect(rewards.player_poptabs).to eql(5000)
    expect(rewards.locker_poptabs).to eql(2500)
    expect(rewards.respect).to eql(7500)
  end
end
