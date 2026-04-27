# frozen_string_literal: true

RSpec.describe ESM::CommunityDefault do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community: community) }

  it "can be created as a global default (no channel_id)" do
    result = create(:community_default, community: community, server: server)
    expect(result.channel_id).to be_nil
  end

  it "can be created with a specific channel_id" do
    channel_id = Faker::Number.number(digits: 18).to_s
    result = create(:community_default, community: community, server: server, channel_id: channel_id)
    expect(result.channel_id).to eq(channel_id)
  end

  describe ".global" do
    it "returns the default with no channel_id" do
      global_default = create(:community_default, community: community, server: server, channel_id: nil)
      create(:community_default, community: community, server: server, channel_id: "123456789")

      expect(described_class.where(community: community, server: server).global).to eq(global_default)
    end
  end
end
