# frozen_string_literal: true

describe ESM::Discord::Bot do
  let(:user) { create(:user) }
  let(:community) { create(:community) }
  let(:channel) { community.discord_server.channels.first }

  it "is not nil" do
    expect(ESM.discord_bot).not_to be_nil
  end

  it "is connected to Discord" do
    wait_for { ESM.discord_bot.connected? }.to be(true)
  end

  describe "#deliver" do
    describe "Sending a string message" do
      it "sends (Channel)" do
        ESM.discord_bot.deliver("Hello!", to: channel.id.to_s)
        ESM.discord_bot.test_outbox.await_size(1)

        message = ESM.discord_bot.test_outbox.first

        # Channel tests
        expect(message.destination).not_to be_nil
        expect(message.destination).to be_kind_of(Discordrb::Channel)
        expect(message.destination.text?).to be(true)

        # Message tests
        expect(message.content).not_to be_nil
        expect(message.content).to be_kind_of(String)
        expect(message.content).to eq("Hello!")
      end

      it "sends (User)" do
        ESM.discord_bot.deliver("Hello!", to: user.discord_id)
        ESM.discord_bot.test_outbox.await_size(1)

        message = ESM.discord_bot.test_outbox.first

        # Channel tests
        expect(message.destination).not_to be_nil
        expect(message.destination).to be_kind_of(Discordrb::Channel)
        expect(message.destination.pm?).to be(true)

        # Message tests
        expect(message.content).not_to be_nil
        expect(message.content).to be_kind_of(String)
        expect(message.content).to eq("Hello!")
      end
    end

    describe "Sending a Embed message" do
      it "sends (Channel)" do
        embed =
          ESM::Embed.build do |e|
            e.title = Faker::Lorem.sentence
            e.description = Faker::Lorem.sentence
          end

        ESM.discord_bot.deliver(embed, to: channel.id.to_s)
        ESM.discord_bot.test_outbox.await_size(1)

        message = ESM.discord_bot.test_outbox.first

        # Channel tests
        expect(message.destination).not_to be_nil
        expect(message.destination).to be_kind_of(Discordrb::Channel)
        expect(message.destination.text?).to be(true)

        # Message tests
        expect(message.content).not_to be_nil
        expect(message.content).to be_kind_of(ESM::Embed)
        expect(message.content.title).to eq(embed.title)
        expect(message.content.description).to eq(embed.description)
      end

      it "sends (User)" do
        ESM.discord_bot.deliver("Hello!", to: user.discord_id)
        ESM.discord_bot.test_outbox.await_size(1)

        message = ESM.discord_bot.test_outbox.first

        # Channel tests
        expect(message.destination).not_to be_nil
        expect(message.destination).to be_kind_of(Discordrb::Channel)
        expect(message.destination.pm?).to be(true)

        # Message tests
        expect(message.content).not_to be_nil
        expect(message.content).to be_kind_of(String)
        expect(message.content).to eq("Hello!")
      end
    end
  end

  describe "#await_response" do
    it "sends and replies (Correct)" do
      ESM.discord_bot.test_inbox.queue_reply(from: user.discord_user, content: "good")
      ESM.discord_bot.deliver("Hello, how are you today?", to: user)
      ESM.discord_bot.await_response(user.discord_id, expected: %w[good bad])

      ESM.discord_bot.test_outbox.await_size(1)
      message = ESM.discord_bot.test_outbox.first

      # Channel
      expect(message.destination).not_to be_nil
      expect(message.destination).to be_kind_of(Discordrb::Channel)
      expect(message.destination.pm?).to be(true)

      # Message tests
      expect(message.content).not_to be_nil
      expect(message.content).to be_kind_of(String)
      expect(message.content).to eq("Hello, how are you today?")
    end

    it "sends and replies (Incorrect)" do
      ESM.discord_bot.deliver("Who wants to party?!?", to: channel)

      # Initial wrong reply, then a correct one .5s later — the bot should
      # accept the second
      ESM.discord_bot.test_inbox.queue_reply(from: user.discord_user, content: "Me!")
      Thread.new do
        sleep(0.5)
        ESM.discord_bot.test_inbox.queue_reply(from: user.discord_user, content: "I do")
      end

      # Start the request (this is blocking)
      ESM.discord_bot.await_response(user.discord_id, expected: ["i do", "i don't"])

      ESM.discord_bot.test_outbox.await_size(2)

      # Channel
      message = ESM.discord_bot.test_outbox.first
      expect(message.destination).not_to be_nil
      expect(message.destination).to be_kind_of(Discordrb::Channel)
      expect(message.destination.text?).to be(true)

      # Message tests
      expect(message.content).not_to be_nil
      expect(message.content).to be_kind_of(String)
      expect(message.content).to eq("Who wants to party?!?")

      # Invalid response
      response = ESM.discord_bot.test_outbox.second.content
      expect(response).not_to be_nil
      expect(response).to eq("I'm sorry, I don't know how to reply to your response.\nI was expecting `i do` or `i don't`")
    end

    it "gives a failed response" do
      expect do
        ESM.discord_bot.await_response(user.discord_id, expected: [], timeout: 0.1)
      end.to raise_error(ESM::Exception::CheckFailure, /failure to communicate/i)
    end
  end

  describe "#wait_for_reply" do
    let(:message) { Faker::String.random }

    it "waits for the reply" do
      ESM.discord_bot.test_inbox.queue_reply(from: user.discord_user, channel: channel, content: message)
      event = ESM.discord_bot.wait_for_reply(user_id: user.discord_id, channel_id: channel.id)
      expect(event).not_to be_nil
      expect(event.message.content).to eq(message)
    end

    it "waits for the reply (With block)" do
      ESM.discord_bot.test_inbox.queue_reply(from: user.discord_user, channel: channel, content: message)
      ESM.discord_bot.wait_for_reply(user_id: user.discord_id, channel_id: channel.id) do |event|
        expect(event).not_to be_nil
        expect(event.message.content).to eq(message)
      end
    end
  end

  describe "#waiting_for_reply?" do
    let(:message) { Faker::String.random }

    it "is waiting for a reply" do
      thread = Thread.new do
        event = ESM.discord_bot.wait_for_reply(user_id: user.discord_id, channel_id: channel.id)
        expect(event).not_to be_nil
        expect(event.message.content).to eq(message)
      end

      sleep(0.2)
      expect(ESM.discord_bot.waiting_for_reply?(user_id: user.discord_id, channel_id: channel.id)).to be(true)

      ESM.discord_bot.test_inbox.queue_reply(from: user.discord_user, channel: channel, content: message)
      thread.join
    end
  end
end
