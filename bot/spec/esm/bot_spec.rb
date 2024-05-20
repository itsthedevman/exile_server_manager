# frozen_string_literal: true

describe ESM::Bot do
  let(:user) { ESM::Test.user }
  let(:community) { ESM::Test.community }
  let(:channel) { ESM::Test.channel(in: community) }

  it "is not nil" do
    expect(ESM.bot).not_to be_nil
  end

  it "is connected to Discord" do
    wait_for { ESM.bot.connected? }.to be(true)
  end

  describe "#deliver" do
    describe "Sending a string message" do
      it "sends (Channel)" do
        ESM.bot.deliver("Hello!", to: channel.id.to_s)
        wait_for { ESM::Test.messages.size }.to eq(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.text?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eq("Hello!")
      end

      it "sends (User)" do
        ESM.bot.deliver("Hello!", to: user.discord_id)
        wait_for { ESM::Test.messages.size }.to eq(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.pm?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eq("Hello!")
      end
    end

    describe "Sending a Embed message" do
      it "sends (Channel)" do
        embed =
          ESM::Embed.build do |e|
            e.title = Faker::Lorem.sentence
            e.description = Faker::Lorem.sentence
          end

        ESM.bot.deliver(embed, to: channel.id.to_s)
        wait_for { ESM::Test.messages.size }.to eq(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.text?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(ESM::Embed)
        expect(message_array.second.title).to eq(embed.title)
        expect(message_array.second.description).to eq(embed.description)
      end

      it "sends (User)" do
        ESM.bot.deliver("Hello!", to: user.discord_id)
        wait_for { ESM::Test.messages.size }.to eq(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.pm?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eq("Hello!")
      end
    end
  end

  describe "#await_response" do
    it "sends and replies (Correct)" do
      ESM::Test.response = "good"
      ESM.bot.deliver("Hello, how are you today?", to: user)
      ESM.bot.await_response(user.discord_id, expected: %w[good bad])

      wait_for { ESM::Test.messages.size }.to eq(1)
      message_array = ESM::Test.messages.first

      # Channel
      expect(message_array.first).not_to be_nil
      expect(message_array.first).to be_kind_of(Discordrb::Channel)
      expect(message_array.first.pm?).to be(true)

      # Message tests
      expect(message_array.second).not_to be_nil
      expect(message_array.second).to be_kind_of(String)
      expect(message_array.second).to eq("Hello, how are you today?")
    end

    it "sends and replies (Incorrect)" do
      ESM.bot.deliver("Who wants to party?!?", to: channel)

      # Set the initial response
      ESM::Test.response = "Me!"

      # "Reply" to the message correctly after 1 second
      ESM::Test.reply_in("I do", wait: 0.5)

      # Start the request (this is blocking)
      ESM.bot.await_response(user.discord_id, expected: ["i do", "i don't"])

      wait_for { ESM::Test.messages.size }.to eq(2)

      # Channel
      message_array = ESM::Test.messages.first
      expect(message_array.destination).not_to be_nil
      expect(message_array.destination).to be_kind_of(Discordrb::Channel)
      expect(message_array.destination.text?).to be(true)

      # Message tests
      expect(message_array.content).not_to be_nil
      expect(message_array.content).to be_kind_of(String)
      expect(message_array.content).to eq("Who wants to party?!?")

      # Invalid response
      response = ESM::Test.messages.second.content
      expect(response).not_to be_nil
      expect(response).to eq("I'm sorry, I don't know how to reply to your response.\nI was expecting `i do` or `i don't`")
    end

    it "gives a failed response" do
      expect do
        ESM.bot.await_response(user.discord_id, expected: [], timeout: 0.1)
      end.to raise_error(ESM::Exception::CheckFailure, /failure to communicate/i)
    end
  end

  describe "#wait_for_reply" do
    let(:message) { Faker::String.random }

    it "waits for the reply" do
      ESM::Test.response = message
      event = ESM.bot.wait_for_reply(user_id: user.id, channel_id: channel.id)
      expect(event).not_to be_nil
      expect(event.message.content).to eq(message)
    end

    it "waits for the reply (With block)" do
      ESM::Test.response = message
      ESM.bot.wait_for_reply(user_id: user.id, channel_id: channel.id) do |event|
        expect(event).not_to be_nil
        expect(event.message.content).to eq(message)
      end
    end
  end

  describe "#waiting_for_reply?" do
    let(:message) { Faker::String.random }

    it "is waiting for a reply" do
      thread = Thread.new do
        expect(ESM::Test.response).to be_nil

        event = ESM.bot.wait_for_reply(user_id: user.id, channel_id: channel.id)
        expect(event).not_to be_nil
        expect(event.message.content).to eq(message)
      end

      sleep(0.2)
      expect(ESM.bot.waiting_for_reply?(user_id: user.id, channel_id: channel.id)).to be(true)

      ESM::Test.response = message
      thread.join
    end
  end
end
