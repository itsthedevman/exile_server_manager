# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::Channel do
  describe ".call" do
    let(:discord_server) { build(:discord_server, channels: %i[general]) }
    let(:community) { create(:community, discord_server: discord_server) }
    let(:channel) { discord_server.channels.first }

    it "returns the channel's serialized form when the bot has send access" do
      result = described_class.call(id: channel.id)
      expect(result[:id].to_i).to eq(channel.id)
    end

    context "when the channel cannot be found" do
      it "returns nil" do
        expect(described_class.call(id: Spec::Snowflake.next)).to be_nil
      end
    end

    context "when the bot has been removed from the channel's guild" do
      before do
        allow(ESM.discord_bot).to receive(:channel_permission?).and_raise(Discordrb::Errors::UnknownServer.new("Unknown Guild"))
      end

      it "returns nil instead of raising" do
        expect(described_class.call(id: channel.id)).to be_nil
      end
    end

    context "with a community_id filter" do
      it "returns nil when the channel belongs to a different community" do
        other_server = build(:discord_server, channels: %i[general])
        other_channel = other_server.channels.first
        expect(described_class.call(id: other_channel.id, community_id: community.id)).to be_nil
      end

      it "returns the channel when it belongs to the community" do
        expect(described_class.call(id: channel.id, community_id: community.id)).not_to be_nil
      end
    end
  end
end
