# frozen_string_literal: true

describe ESM::Connection::MessageOverseer, v2: true do
  let!(:overseer) { ESM::Connection::Server.instance.message_overseer }
  let!(:message) { ESM::Message.event }

  describe "#watch" do
    it "adds the message to the watch list" do
      expect { overseer.watch(message) }.not_to raise_error
      expect(overseer.instance_variable_get(:@mailbox).size).to eq(1)
    end

    it "times out and calls on_error" do
      message.add_callback(:on_error) do |incoming|
        expect(incoming).to be_nil
      end

      expect { overseer.watch(message, expires_at: Time.now) }.not_to raise_error

      wait_for { message.delivered? }.to be(true)

      expect(message.errors?).to be(true)
      expect(message.errors.first.type).to eq(:code)
      expect(message.errors.first.content).to eq("message_undeliverable")
    end
  end

  describe "#retrieve" do
    it "returns the message based on its id" do
      expect { overseer.watch(message) }.not_to raise_error

      expect(overseer.retrieve(message.id)).to eq(message)
    end
  end
end
