# frozen_string_literal: true

describe ESM::Connection::Server, v2: true do
  include_context "connection"

  let(:connection_server) { described_class.instance }
  let(:server) { ESM::Test.server }
  let(:message) { ESM::Message.event }

  describe "#on_message" do
    it "triggers on_error if message contains errors" do
      outgoing_message = ESM::Message.event.set_id(message.id)
      outgoing_message.add_error(:code, "default")

      # Remove the default callback and set a new one
      outgoing_message.add_callback(:on_error) do |incoming|
        expect(errors.first.to_h).to eql({type: :code, content: "default"})
      end

      # The overseer needs to know about this message
      connection_server.message_overseer.watch(outgoing_message)

      expect { connection_server.send(:on_message, server.uuid, message) }.not_to raise_error
    end
  end

  # fire(message, to:, forget: false)
  describe "#fire", requires_connection: true do
    before do
      ESM::Test.block_outbound_messages = true
    end

    after do
      connection_server.message_overseer.remove_all!
    end

    it "sends a message" do
      expect { connection_server.fire(message, to: server.uuid, forget: true) }.not_to raise_error

      outgoing_message = ESM::Test.outbound_server_messages.first
      expect(outgoing_message).not_to be_nil

      expect(outgoing_message.destination).to eq(server.uuid)
      expect(outgoing_message.content).to eq(message)
    end

    it "sends a message and waits for the reply" do
      outgoing_message = ESM::Message.event.set_id(message.id)

      thread = Thread.new do
        response = nil
        expect { response = connection_server.fire(outgoing_message, to: server.uuid) }.not_to raise_error
        expect(response).not_to be_nil
        expect(response.type).to eq(:event)
        expect(response.data_type).to eq(:empty)
      end

      sleep(0.2)

      expect(connection_server.message_overseer.size).to eq(1)
      expect { connection_server.send(:on_message, server.uuid, message) }.not_to raise_error
      expect(connection_server.message_overseer.size).to eq(0)

      thread.join

      message = ESM::Test.outbound_server_messages.first
      expect(message).not_to be_nil

      expect(message.destination).to eq(server.uuid)
      expect(message.content.to_h).to eq(outgoing_message.to_h)
    end
  end
end
