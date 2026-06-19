# frozen_string_literal: true

describe ESM::Discord::Bot::DeliveryOverseer do
  # check_every: 0 removes the inter-send pacing so the workers drain as fast as the test can assert. The pacing itself
  # is discordrb's concern, not this spec's.
  subject(:overseer) { described_class.new(check_every: 0) }

  let(:channel) { instance_double(Discordrb::Channel) }
  let(:sent_message) { instance_double(Discordrb::Message) }

  # Records every send the workers hand off to the bot, so assertions can poll for asynchronous delivery instead of
  # racing the worker threads.
  let(:deliveries) { Concurrent::Array.new }

  before do
    allow(ESM.discord_bot).to receive(:__deliver) do |message, delivery_channel, **kwargs|
      deliveries << {message:, delivery_channel:, **kwargs}
      sent_message
    end
  end

  describe "#add" do
    context "when wait is false" do
      it "returns nil rather than a promise" do
        expect(overseer.add("Hello!", channel)).to be_nil
      end

      it "still delivers the message through a worker" do
        overseer.add("Hello!", channel)

        wait_for { deliveries.size }.to eq(1)
        expect(deliveries.first).to include(message: "Hello!", delivery_channel: channel)
      end

      it "forwards embed_message and replying_to to the delivery" do
        reply = instance_double(Discordrb::Message)
        overseer.add("Hello!", channel, embed_message: "ping", replying_to: reply)

        wait_for { deliveries.size }.to eq(1)
        expect(deliveries.first).to include(embed_message: "ping", replying_to: reply)
      end
    end

    context "when wait is true" do
      it "returns a promise" do
        expect(overseer.add("Hello!", channel, wait: true)).to be_a(Concurrent::IVar)
      end

      it "resolves the promise with the delivered message" do
        promise = overseer.add("Hello!", channel, wait: true)

        expect(promise.value(5)).to eq(sent_message)
      end

      # The bug that motivated the rewrite: the message was sent but the caller received nil. The value must survive the
      # trip from worker to caller.
      it "carries the exact message object the bot returned" do
        specific_message = instance_double(Discordrb::Message)
        allow(ESM.discord_bot).to receive(:__deliver).and_return(specific_message)

        promise = overseer.add("Hello!", channel, wait: true)

        expect(promise.value(5)).to be(specific_message)
      end
    end
  end

  describe "delivery" do
    it "drains every queued message" do
      messages = %w[one two three four five]
      messages.each { |message| overseer.add(message, channel) }

      wait_for { deliveries.size }.to eq(messages.size)
      expect(deliveries.map { |d| d[:message] }).to match_array(messages)
    end

    context "when a delivery raises" do
      it "resolves the waiting promise with nil" do
        allow(ESM.discord_bot).to receive(:__deliver).and_raise("Discord is on fire")

        promise = overseer.add("Hello!", channel, wait: true)

        expect(promise.value(5)).to be_nil
      end

      it "keeps the worker alive for the next delivery" do
        call_count = Concurrent::AtomicFixnum.new(0)
        allow(ESM.discord_bot).to receive(:__deliver) do
          raise "boom" if call_count.increment == 1

          sent_message
        end

        overseer.add("first", channel, wait: true).value(5)

        second = overseer.add("second", channel, wait: true)
        expect(second.value(5)).to eq(sent_message)
      end
    end
  end

  describe "the worker pool" do
    it "delivers on multiple workers in parallel" do
      active = Concurrent::AtomicFixnum.new(0)
      peak = Concurrent::AtomicFixnum.new(0)

      allow(ESM.discord_bot).to receive(:__deliver) do
        in_flight = active.increment
        peak.update { |current| [current, in_flight].max }
        sleep(0.1)
        active.decrement

        sent_message
      end

      overseer.add("one", channel)
      overseer.add("two", channel)

      wait_for { peak.value }.to eq(2)
    end
  end
end
