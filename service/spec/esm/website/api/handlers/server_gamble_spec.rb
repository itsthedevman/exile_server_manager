# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::ServerGamble do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let!(:user) { create(:user) }

  let!(:command) do
    ESM::ServerCommand.create!(
      user:,
      server:,
      idempotency_key: SecureRandom.uuid,
      command_name: "server_gamble",
      arguments: {territory_id: "abc123"},
      status: :pending
    )
  end

  def call
    described_class.call(command_id: command.id)
  end

  describe ".call" do
    # The handler offloads the Arma round-trip to a real Concurrent::Promise, so
    # the row settles on another thread. Deletion (not transaction) cleaning means
    # those writes are visible here, so we wait for the terminal status.
    context "when the sqf call succeeds" do
      before do
        allow_any_instance_of(ESM::Server).to receive(:call_sqf_function!).and_return(true)
      end

      it "completes the row" do
        call

        wait_for { command.reload.status }.to eq("completed")
      end
    end

    context "when the sqf call times out" do
      # send_request re-raises the promise's RequestTimeout (client.rb:113) when the
      # Arma round-trip never answers. This is the path that must NOT be recorded as
      # a success: the payment may or may not have happened, so the row is timed_out.
      before do
        allow_any_instance_of(ESM::Server)
          .to receive(:call_sqf_function!)
          .and_raise(ESM::Exception::RequestTimeout)
      end

      it "marks the row timed_out, not completed" do
        call

        wait_for { command.reload.status }.to eq("timed_out")
      end
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
