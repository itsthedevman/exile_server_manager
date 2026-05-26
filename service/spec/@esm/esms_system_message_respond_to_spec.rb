# frozen_string_literal: true

describe "ESMs_system_message_respond_to", :requires_connection, v2: true do
  include_context "connection"

  it "acknowledges the message" do
    original_message = ESM::Message.new

    # Register a pending promise without sending anything; the response is triggered
    # directly by the execute_sqf! call below.
    promise = server.connection.register_response(original_message.id)

    execute_sqf!(
      <<~SQF
        ["#{original_message.id}"] call ESMs_system_message_respond_to;
      SQF
    )

    # Now we can read the response from the SQF
    response = promise.wait_for_response
    expect(response.fulfilled?).to be(true)

    message = ESM::Message.from_string(response.value)

    expect(message.id).to eq(original_message.id)
    expect(message.type).to eq(:ack)
    expect(message.data).to be_kind_of(ESM::Message::Data)
    expect(message.data.to_h).to eq({})
    expect(message.metadata).to be_kind_of(ESM::Message::Metadata)
    expect(message.metadata.to_h).to eq({})
    expect(message.errors).to eq([])
  end
end
