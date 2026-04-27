# frozen_string_literal: true

describe ESM::Connection::Promise, v2: true do
  subject(:promise) { described_class.new }

  context "when the inner value is set and the promise is told to wait for a response" do
    let(:response) { ESM::Connection::Request.from_client(t: 0, c: "[1, 2, 3]".bytes) }

    it "returns the inner value" do
      promise.then do |_|
        sleep(0.1)
        true
      end

      promise.execute
      promise.set_response(response)

      received_response = promise.wait_for_response
      expect(received_response).to be_kind_of(ESM::Connection::Response)
      expect(received_response.fulfilled?).to be(true)
      expect(received_response.value).to eq("[1, 2, 3]")
    end
  end

  context "when a chain in the promise raises an exception" do
    it "returns a rejected response with the exception" do
      promise.then do |_|
        raise StandardError, "Uh-oh"
      end

      promise.execute

      response = promise.wait_for_response
      expect(response).to be_kind_of(ESM::Connection::Response)
      expect(response.rejected?).to be(true)
      expect(response.reason).to be_kind_of(StandardError)
      expect(response.reason.message).to eq("Uh-oh")
    end
  end
end
