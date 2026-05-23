# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::ServersConnected do
  describe ".call" do
    let(:community) { create(:community) }
    let(:server) { create(:server, community_id: community.id) }

    it "returns the server's connection state" do
      allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)
      expect(described_class.call(id: server.id)).to be(true)
    end

    it "returns false when the server is disconnected" do
      allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
      expect(described_class.call(id: server.id)).to be(false)
    end

    context "when the server is missing" do
      it "returns nil without raising" do
        expect(described_class.call(id: -1)).to be_nil
      end
    end
  end
end
