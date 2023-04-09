# frozen_string_literal: true

describe "ESMs_system_message_respond_to", requires_connection: true, v2: true do
  include_context "connection"

  it "acknowledges the message" do
    success = false
    outbound_message = ESM::Message.event

    outbound_message.add_callback(:on_response) do |inbound|
      expect(inbound.type).to eq(:event)
      expect(inbound.id).to eq(outbound_message.id)
      expect(inbound.data_type).to eq(:empty)
      expect(inbound.data).to eq({})
      expect(inbound.metadata_type).to eq(:empty)
      expect(inbound.metadata).to eq({})
      expect(inbound.errors).to eq([])

      success = true
    end

    # Needed for the message cycle to properly complete
    connection.tcp_server.message_overseer.watch(outbound_message)

    execute_sqf!(
      <<~SQF
        ["#{outbound_message.id}"] call ESMs_system_message_respond_to;
      SQF
    )

    expect(success).to be(true)
  end

  it "on_error is triggered when errors" do
    success = false
    outbound_message = ESM::Message.event

    outbound_message.add_callback(:on_error) do |inbound|
      expect(inbound.type).to eq(:event)
      expect(inbound.id).to eq(outbound_message.id)
      expect(inbound.data_type).to eq(:empty)
      expect(inbound.data).to eq({})
      expect(inbound.metadata_type).to eq(:empty)
      expect(inbound.metadata).to eq({})

      errors = inbound.errors.map(&:to_h)
      expect(errors).to include({type: :code, content: "ERROR_CODE"})
      expect(errors).to include({type: :message, content: "An error message"})

      success = true
    end

    # Needed for the message cycle to properly complete
    connection.tcp_server.message_overseer.watch(outbound_message)

    execute_sqf!(
      <<~SQF
        ["#{outbound_message.id}", "event", "empty", [], "empty", [], [["code", "ERROR_CODE"], ["message", "An error message"]]] call ESMs_system_message_respond_to;
      SQF
    )

    expect(success).to be(true)
  end
end
