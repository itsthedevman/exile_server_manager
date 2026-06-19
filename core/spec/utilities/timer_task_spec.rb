# frozen_string_literal: true

RSpec.describe ESM::TimerTask do
  describe ".execute" do
    # The work runs on a background timer thread, so reach past Concurrent and capture the block it
    # hands off, then drive it synchronously. The rescue wrapper is the only behavior this class adds.
    subject(:wrapped_task) do
      captured = nil
      allow(Concurrent::TimerTask).to receive(:execute) { |**_options, &block| captured = block }

      described_class.execute(&work)
      captured
    end

    before { allow(ESM.logger).to receive(:error!) }

    context "when the work raises a StandardError" do
      let(:work) { -> { raise ArgumentError, "boom" } }

      it "logs the error and swallows it" do
        expect { wrapped_task.call }.not_to raise_error
        expect(ESM.logger).to have_received(:error!).with(error: an_instance_of(ArgumentError))
      end
    end

    context "when the work raises outside the StandardError hierarchy" do
      let(:work) { -> { raise SystemStackError } }

      it "logs the error and swallows it" do
        expect { wrapped_task.call }.not_to raise_error
        expect(ESM.logger).to have_received(:error!).with(error: an_instance_of(SystemStackError))
      end
    end
  end
end
