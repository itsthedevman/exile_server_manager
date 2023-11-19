# frozen_string_literal: true

describe ESM::CommunityDefault do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let(:channel) { ESM::Test.channel }

  it "is valid" do
    expect {
      # A default can be global for the entire Discord
      result = create(:community_default, community: community, server: server)
      expect(result.channel_id).to be(nil)

      # Or local to a channel
      create(:community_default, community: community, server: server, channel_id: channel.id.to_s)
    }.not_to raise_error
  end
end
