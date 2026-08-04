# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::AsyncCommand do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let!(:user) { create(:user) }

  let!(:service_command) do
    ESM::ServiceCommand.create!(
      user:,
      server:,
      community:,
      idempotency_key: SecureRandom.uuid,
      command_name: "gamble",
      arguments: {server_id: server.server_id},
      status: :pending
    )
  end

  describe ".call" do
    # The handler offloads to a real Concurrent::Promise. Run it inline so the delegation is
    # observable synchronously; the real offload is exercised by the command's own workflow spec.
    before do
      allow(Concurrent::Promise).to receive(:execute) { |&block| block.call }
    end

    it "dispatches the row through its command's website event hook" do
      expect(ESM::Command::Server::Gamble).to receive(:website_async_hook).with(
        an_instance_of(ESM::ServiceCommand)
      )

      described_class.call(command_id: service_command.id)
    end

    context "when the command id is unknown" do
      it "raises ArgumentError" do
        expect {
          described_class.call(command_id: "does-not-exist")
        }.to raise_error(ArgumentError, /Unknown command/)
      end
    end
  end
end
