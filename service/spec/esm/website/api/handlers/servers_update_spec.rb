# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::ServersUpdate do
  describe ".call" do
    let(:community) { create(:community) }
    let(:server) { create(:server, community_id: community.id) }

    context "on a v2 server with a live connection" do
      let(:connection) { double("connection", close: nil, connected?: false) }

      before do
        # Wait for the factory to settle (after_save callbacks fire during create)
        # before stubbing — otherwise the connection stub takes effect inside
        # ServerSetting#update_arma and confuses the assertion.
        server
        allow_any_instance_of(ESM::Server).to receive(:v2?).and_return(true)
        allow_any_instance_of(ESM::Server).to receive(:connection).and_return(connection)
      end

      it "closes the connection with the settings-update reason" do
        expect(connection).to receive(:close).with(I18n.t("server_reconnect.reasons.settings_update"))
        described_class.call(id: server.id)
      end
    end

    context "on a v2 server with no live connection" do
      before do
        server
        allow_any_instance_of(ESM::Server).to receive(:v2?).and_return(true)
        allow_any_instance_of(ESM::Server).to receive(:connection).and_return(nil)
      end

      it "returns true" do
        expect(described_class.call(id: server.id)).to be(true)
      end
    end

    context "when the server is missing" do
      it "returns nil without raising" do
        expect(described_class.call(id: -1)).to be_nil
      end
    end
  end
end
