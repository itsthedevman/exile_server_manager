# frozen_string_literal: true

describe "ESMs_system_message_respond_withError", :requires_connection, v2: true do
  include_context "connection"

  context "when errors are provided" do
    it "contains the errors" do
      original_message = ESM::Message.new

      promise = server.connection
        .write(type: :message, id: original_message.id, content: nil)
        .reset_promise

      execute_sqf!(
        <<~SQF
          [
            "#{original_message.id}",
            "ack",
            [],
            [],
            [["code", "ERROR_CODE"], ["message", "An error message"]]
          ] call ESMs_system_message_respond_to;
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

      errors = message.errors.map(&:to_h)
      expect(errors).to include({type: :code, content: "ERROR_CODE"})
      expect(errors).to include({type: :message, content: "An error message"})
    end
  end
end
