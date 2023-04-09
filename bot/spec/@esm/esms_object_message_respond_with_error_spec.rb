# frozen_string_literal: true

describe "ESMs_system_message_respond_withError", requires_connection: true, v2: true do
  include_context "connection"

  it "responds with an error" do
    success = false
    outbound_message = ESM::Message.event

    outbound_message.add_callback(:on_error) do |inbound|
      expect(inbound.id).to eq(outbound_message.id)
      expect(inbound.type).to eq(:event)
      expect(inbound.data_type).to eq(:empty)
      expect(inbound.data).to eq({})
      expect(inbound.metadata_type).to eq(:empty)
      expect(inbound.metadata).to eq({})

      errors = inbound.errors.map(&:to_h)
      expect(errors).to include({type: :message, content: "An error message"})

      success = true
    end

    # Needed for the message cycle to properly complete
    connection.tcp_server.message_overseer.watch(outbound_message)

    execute_sqf!(
      <<~SQF
        ["#{outbound_message.id}", "An error message"] call ESMs_system_message_respond_withError;
      SQF
    )

    expect(success).to be(true), "Asynchronous response callback experienced an issue - Check logs for \"terminated with exception\""
  end
end
