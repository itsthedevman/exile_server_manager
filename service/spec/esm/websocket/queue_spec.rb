# frozen_string_literal: true

describe ESM::Websocket::Queue do
  let(:params) { {foo: "Foo", bar: ["Bar"], baz: false} }
  let(:request) { create_request(**params) }
  let(:queue) do
    queue = ESM::Websocket::Queue.new
    queue << request
    queue
  end

  describe "#<<" do
    it "adds a request" do
      expect(queue.size).to eq(1)
    end
  end

  describe "#first" do
    it "gets the first request" do
      expect(queue.first.to_s).to eq(request.to_s)
    end
  end

  describe "#remove" do
    it "removes" do
      queue.remove(request.id)
      expect(queue.size).to eq(0)
    end
  end
end
