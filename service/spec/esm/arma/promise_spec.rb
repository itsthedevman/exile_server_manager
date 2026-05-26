# frozen_string_literal: true

describe ESM::Arma::Promise, v2: true do
  subject(:promise) { described_class.new }

  let(:request) { ESM::Arma::Request.from_client(t: 0, c: "[1, 2, 3]".bytes) }

  describe "#wait_for_response" do
    context "when a response has been set" do
      it "returns a fulfilled obligation carrying the response content" do
        promise.set_response(request)

        response = promise.wait_for_response
        expect(response.fulfilled?).to be(true)
        expect(response.value).to eq("[1, 2, 3]")
      end
    end

    context "when the response is a StandardError" do
      it "returns a rejected obligation carrying the error" do
        error = StandardError.new("Uh-oh")
        promise.set_response(error)

        response = promise.wait_for_response
        expect(response.rejected?).to be(true)
        expect(response.reason).to eq(error)
      end
    end

    context "when no response arrives before the timeout" do
      it "rejects with a RequestTimeout" do
        response = promise.wait_for_response(0.05)

        expect(response.rejected?).to be(true)
        expect(response.reason).to be_kind_of(ESM::Exception::RequestTimeout)
      end
    end
  end

  describe "#on_response" do
    it "invokes the callback with the resolved obligation when a response arrives" do
      received = Concurrent::IVar.new
      promise.on_response(1) { |response| received.set(response) }

      promise.set_response(request)

      response = received.value(1)
      expect(response).not_to be_nil
      expect(response.fulfilled?).to be(true)
      expect(response.value).to eq("[1, 2, 3]")
    end

    it "rejects with a RequestTimeout when no response arrives in time" do
      received = Concurrent::IVar.new
      promise.on_response(0.05) { |response| received.set(response) }

      response = received.value(1)
      expect(response).not_to be_nil
      expect(response.rejected?).to be(true)
      expect(response.reason).to be_kind_of(ESM::Exception::RequestTimeout)
    end
  end
end
