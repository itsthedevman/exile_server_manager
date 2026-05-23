# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::ServersReconnect do
  describe ".call" do
    let(:community) { create(:community) }
    let(:server) { create(:server, community_id: community.id) }

    context "when old_id is blank" do
      it "returns nil without touching the websocket layer" do
        expect(ESM::Websocket).not_to receive(:connection)
        expect(described_class.call(id: server.id, old_id: "")).to be_nil
      end
    end

    context "when there is no websocket connection for old_id" do
      before { allow(ESM::Websocket).to receive(:connection).with("old_id").and_return(nil) }

      it "returns nil" do
        expect(described_class.call(id: server.id, old_id: "old_id")).to be_nil
      end
    end

    context "when the server is missing" do
      it "returns nil without raising" do
        expect(described_class.call(id: -1, old_id: "old_id")).to be_nil
      end
    end
  end
end
