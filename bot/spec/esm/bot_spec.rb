# frozen_string_literal: true

describe ESM::Bot do
  it "should not be nil" do
    expect(ESM.bot).not_to be_nil
  end

  it "should be connected to Discord" do
    wait_for { ESM.bot.connected? }.to be(true)
  end

  it "should return a channel" do
    expect(ESM.bot.channel(ESM::Community::Secondary::SPAM_CHANNEL)).to be_a(Discordrb::Channel)
  end

  describe "#deliver" do
    describe "Sending a string message" do
      it "should send (Channel)" do
        ESM.bot.deliver("Hello!", to: ESM::Community::ESM::SPAM_CHANNEL)
        expect(ESM::Test.messages.size).to eql(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.text?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eql("Hello!")
      end

      it "should send (User)" do
        ESM.bot.deliver("Hello!", to: ESM::User::Bryan::ID)
        expect(ESM::Test.messages.size).to eql(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.pm?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eql("Hello!")
      end
    end

    describe "Sending a Embed message" do
      it "should send (Channel)" do
        embed =
          ESM::Embed.build do |e|
            e.title = Faker::Lorem.sentence
            e.description = Faker::Lorem.sentence
          end

        ESM.bot.deliver(embed, to: ESM::Community::ESM::SPAM_CHANNEL)
        expect(ESM::Test.messages.size).to eql(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.text?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(ESM::Embed)
        expect(message_array.second.title).to eql(embed.title)
        expect(message_array.second.description).to eql(embed.description)
      end

      it "should send (User)" do
        ESM.bot.deliver("Hello!", to: ESM::User::Bryan::ID)
        expect(ESM::Test.messages.size).to eql(1)

        message_array = ESM::Test.messages.first

        # Channel tests
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.pm?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eql("Hello!")
      end
    end
  end

  describe "#deliver_and_await!" do
    describe "Send to user" do
      it "should send and reply (Correct)" do
        ESM::Test.response = "good"
        ESM.bot.deliver_and_await!("Hello, how are you today?", to: ESM::User::Bryan::ID, expected: %w[good bad])

        expect(ESM::Test.messages.size).to eql(1)
        message_array = ESM::Test.messages.first

        # Channel
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.pm?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eql("Hello, how are you today?")
      end
    end

    describe "Send to channel" do
      before :each do
        # Set the initial response
        ESM::Test.response = "Me!"

        # Cause the Reset the response to nil after 0.5 seconds
        ESM::Test.await_and_reply(nil, wait: 0.5)

        # "Reply" to the message correctly after 1 second
        ESM::Test.await_and_reply("I do", wait: 0.55)
      end

      it "should send and reply (Incorrect)" do
        # Start the request
        ESM.bot.deliver_and_await!(
          "Who wants to party?!?",
          to: ESM::Community::ESM::SPAM_CHANNEL,
          owner: ESM::User::Bryan::ID,
          expected: ["i do", "i don't"]
        )

        expect(ESM::Test.messages.size).to eql(2)
        message_array = ESM::Test.messages.first
        response = ESM::Test.messages.second[1]

        # Channel
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.text?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eql("Who wants to party?!?")

        # Invalid response
        expect(response).not_to be_nil
        expect(response).to eql("I'm sorry, I don't know how to reply to your response.\nI was expecting `i do` or `i don't`")
      end

      it "should send and reply (Incorrect/Custom Response)" do
        # Start the request
        ESM.bot.deliver_and_await!(
          "Who wants to party?!?",
          to: ESM::Community::ESM::SPAM_CHANNEL,
          owner: ESM::User::Bryan::ID,
          expected: ["i do", "i don't"],
          invalid_response: "Noup" # Useful!
        )

        expect(ESM::Test.messages.size).to eql(2)
        message_array = ESM::Test.messages.first
        response = ESM::Test.messages.second[1]

        # Channel
        expect(message_array.first).not_to be_nil
        expect(message_array.first).to be_kind_of(Discordrb::Channel)
        expect(message_array.first.text?).to be(true)

        # Message tests
        expect(message_array.second).not_to be_nil
        expect(message_array.second).to be_kind_of(String)
        expect(message_array.second).to eql("Who wants to party?!?")

        # Invalid response
        expect(response).not_to be_nil
        expect(response).to eql("Noup")
      end
    end

    it "should give a failed response" do
      expect do
        ESM.bot.deliver_and_await!("Who wants to party?!?", to: ESM::Community::ESM::SPAM_CHANNEL, owner: ESM::User::Bryan::ID, expected: [], give_up_after: 0)
      end.to raise_error(ESM::Exception::CheckFailure, /failure to communicate/i)
    end
  end

  it "should not have a Community created" do
    expect(ESM::Community.where(guild_id: ESM::Community::ESM::ID).first).to be_nil
  end
end
