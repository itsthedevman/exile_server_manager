# frozen_string_literal: true

describe ESM::Bot::ResendQueue do
  let!(:queue) { ESM.bot.resend_queue }
  let!(:channel) { ESM::Community::ESM::SPAM_CHANNEL }
  let!(:message) { Faker::Lorem.sentence }

  # I need a backtrace
  let!(:exception) do
    raise StandardError, "Great."
  rescue StandardError => e
    e
  end

  describe "#enqueue" do
    before :each do
      # Stop processing so values can be inspected
      queue.pause
    end

    it "should add to queue" do
      queue.enqueue(message, to: channel, exception: exception)

      expect(queue.size).to eql(1)
    end

    it "should only add once" do
      queue.enqueue(message, to: channel, exception: exception)
      queue.enqueue(message, to: channel, exception: exception)

      expect(queue.size).to eql(1)
    end

    it "should have proper values" do
      queue.enqueue(message, to: channel, exception: exception)
      expect(queue.size).to eql(1)

      entry = queue.entries.find { |obj| obj.message == message && obj.to == channel }

      # Check exception
      expect(entry.exception).not_to be(nil)
      expect(entry.exception.message).to eql("Great.")

      # Check message
      expect(entry.message).to eql(message)

      # Check to channel
      expect(entry.to).to eql(channel)

      # Check iteration
      expect(entry.attempt).to eql(1)
    end
  end

  describe "#dequeue" do
    it "should remove the message from the queue" do
      # Stop processing so values can be inspected
      queue.pause

      queue.enqueue(message, to: channel, exception: exception)
      expect(queue.size).to eql(1)

      queue.dequeue(message, to: channel)
      expect(queue.size).to eql(0)
    end
  end

  describe "#process_queue" do
    it "should successfully resend the message" do
      queue.enqueue(message, to: channel, exception: exception)
      expect(queue.size).to eql(1)
      sleep(1)

      expect(ESM::Test.messages.size).to eql(1)
      expect(queue.size).to eql(0)
    end

    it "should fail to resend the message" do
      queue.enqueue(message, to: "noup", exception: exception)
      expect(queue.size).to eql(1)

      entry = queue.entries.find { |obj| obj.message == message && obj.to == "noup" }

      # Very tiny window to check these while the loop is running.
      # These are timed out for my machine, I have no idea if it will break on another's

      # Attempt 1
      expect(ESM::Test.messages.size).to eql(0)
      expect(queue.size).to eql(1)
      expect(entry.attempt).to eql(1)

      # Attempt 2
      sleep(0.6)
      expect(ESM::Test.messages.size).to eql(0)
      expect(queue.size).to eql(1)
      expect(entry.attempt).to eql(2)

      # Attempt 3
      sleep(0.7)
      expect(ESM::Test.messages.size).to eql(0)
      expect(queue.size).to eql(1)
      expect(entry.attempt).to eql(3)

      # Attempt 4
      sleep(0.8)
      expect(ESM::Test.messages.size).to eql(0)
      expect(queue.size).to eql(1)
      expect(entry.attempt).to eql(4)

      # Attempt 5
      sleep(0.7)
      expect(ESM::Test.messages.size).to eql(0)
      expect(queue.size).to eql(1)
      expect(entry.attempt).to eql(5)

      # It should be dequeued
      sleep(1)
      expect(ESM::Test.messages.size).to eql(0)
      expect(queue.size).to eql(0)
    end
  end
end
