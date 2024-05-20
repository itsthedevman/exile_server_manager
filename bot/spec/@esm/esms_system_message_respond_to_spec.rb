# frozen_string_literal: true

describe "ESMs_system_message_respond_to", :requires_connection, v2: true do
  include_context "connection"

  it "acknowledges the message" do
    original_message = ESM::Message.new

    # Resetting the promise back to the start removes any "#then" method chains
    # The reason why this is important is to ensure the spec can handle the incoming
    # data.
    promise = server.connection
      .write(type: :message, id: original_message.id, content: nil)
      .reset_promise

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
