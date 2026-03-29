# frozen_string_literal: true

RSpec.describe ESM::Community do
  describe ".find_by_server_id" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }

    it "finds the community by a server id" do
      result = described_class.find_by_server_id(server.server_id)
      expect(result).not_to be_nil
      expect(result).to eq(community)
    end

    it "returns nil when given nil" do
      expect(described_class.find_by_server_id(nil)).to be_nil
    end

    it "returns nil when given empty string" do
      expect(described_class.find_by_server_id("")).to be_nil
    end

    it "returns nil when server_id doesn't exist" do
      expect(described_class.find_by_server_id("nonexistent_server")).to be_nil
    end

    it "returns nil for malformed server_id" do
      expect(described_class.find_by_server_id("invalid")).to be_nil
    end
  end
end
