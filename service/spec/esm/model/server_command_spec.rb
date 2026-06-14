# frozen_string_literal: true

RSpec.describe ESM::ServerCommand do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let!(:user) { create(:user) }

  subject(:command) do
    described_class.create!(
      user:,
      server:,
      idempotency_key: SecureRandom.uuid,
      command_name: "territory_pay",
      status: :pending
    )
  end

  describe "#execute" do
    # Run the promise body inline so the state transitions are observable
    # synchronously; the real offload is exercised by the handler specs.
    before do
      allow(Concurrent::Promise).to receive(:execute) { |&block| block.call }
    end

    it "marks the row completed when the block succeeds" do
      command.execute { :ok }

      expect(command.reload.status).to eq("completed")
    end

    it "marks the row timed_out when the block raises RequestTimeout" do
      command.execute { raise ESM::Exception::RequestTimeout }

      expect(command.reload.status).to eq("timed_out")
    end

    it "marks the row failed and records the message on an ExtensionError" do
      command.execute do
        raise ESM::Exception::ExtensionError.new(["You do not have enough poptabs"])
      end

      expect(command.reload.status).to eq("failed")
      expect(command.reload.error_message).to eq("You do not have enough poptabs")
    end

    it "joins multiple ExtensionError messages onto the row" do
      command.execute do
        raise ESM::Exception::ExtensionError.new(["First problem", "Second problem"])
      end

      expect(command.reload.error_message).to eq("First problem\nSecond problem")
    end

    it "marks the row failed but records nothing on an unexpected error" do
      command.execute { raise "boom" }

      expect(command.reload.status).to eq("failed")
      expect(command.reload.error_message).to be_nil
    end

    it "returns self so the handler can ack immediately" do
      expect(command.execute { :ok }).to eq(command)
    end
  end
end
