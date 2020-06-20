# frozen_string_literal: true

describe ESM::Event::DiscordMessageChannel do
  let!(:community) { create(:esm_community) }
  let!(:server) { create(:server, community_id: community.id) }

  def event(params)
    ESM::Event::DiscordMessageChannel.new(server, params)
  end

  describe "Errors" do
    it "should not send to other community channel" do
      params = OpenStruct.new(channelID: ESM::Community::Secondary::SPAM_CHANNEL, message: "TESTING!")

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)
      message = ESM::Test.messages.first.second

      expect(message).to eql("**[`ESM_fnc_sendToChannel`]**\nYour Discord Server does not have a channel with ID `#{params.channelID}`. Please provide `ESM_fnc_sendToChannel` a channel ID that belongs to your Discord Server.")
    end

    it "should log and not send (Malformed)" do
      params = OpenStruct.new(channelID: community.logging_channel_id, message: '["title", "description"]')

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)
      message = ESM::Test.messages.first.second

      expect(message).to eql("**[`ESM_fnc_sendToChannel`]**\nThe provided message is malformed and unable to be delivered.\nPlease read the API documentation on my website (https://www.esmbot.com/wiki/api) for the correct format.\nThis is the message I attempted to send: ```#{params.message}```")
    end
  end

  describe "Sending String" do
    it "should send" do
      params = OpenStruct.new(channelID: community.logging_channel_id, message: "TESTING!")

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)
      channel, message = ESM::Test.messages.first

      expect(channel.id.to_s).to eql(params.channelID)
      expect(message).to eql(params.message)
    end
  end

  describe "Sending Embed" do
    it "should send (Const Color)" do
      params = OpenStruct.new(
        channelID: community.logging_channel_id,
        message: [
          "Title",
          "Description",
          [["Field 1 Name", "Field 1 Value", true], ["Field 2 Name", "Field 2 Value", false], ["Field 3 Name", "Field 3 Value", true]],
          "blue"
        ].to_json
      )

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)
      channel, embed = ESM::Test.messages.first

      expect(channel.id.to_s).to eql(params.channelID)
      expect(embed.title).to eql("Title")
      expect(embed.description).to eql("Description")
      expect(embed.fields.size).to eql(3)
      expect(embed.fields.first.name).to eql("Field 1 Name")
      expect(embed.fields.first.value).to eql("Field 1 Value")
      expect(embed.fields.first.inline).to eql(true)
      expect(embed.color).to eql(ESM::Color::Toast::BLUE)
    end

    it "should send (Hex Color)" do
      params = OpenStruct.new(
        channelID: community.logging_channel_id,
        message: [
          "Title",
          "Description",
          [["Field 1 Name", "Field 1 Value", true], ["Field 2 Name", "Field 2 Value", false], ["Field 3 Name", "Field 3 Value", true]],
          "#1e354D"
        ].to_json
      )

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)
      channel, embed = ESM::Test.messages.first

      expect(channel.id.to_s).to eql(params.channelID)
      expect(embed.title).to eql("Title")
      expect(embed.description).to eql("Description")
      expect(embed.fields.size).to eql(3)
      expect(embed.fields.first.name).to eql("Field 1 Name")
      expect(embed.fields.first.value).to eql("Field 1 Value")
      expect(embed.fields.first.inline).to eql(true)
      expect(embed.color.upcase).to eql(ESM::Color::BLUE)
    end

    it "should send (Invalid/Random Color)" do
      params = OpenStruct.new(
        channelID: community.logging_channel_id,
        message: [
          "Title",
          "Description",
          [["Field 1 Name", "Field 1 Value", true], ["Field 2 Name", "Field 2 Value", false], ["Field 3 Name", "Field 3 Value", true]],
          "BLACK"
        ].to_json
      )

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)
      channel, embed = ESM::Test.messages.first

      expect(channel.id.to_s).to eql(params.channelID)
      expect(embed.title).to eql("Title")
      expect(embed.description).to eql("Description")
      expect(embed.fields.size).to eql(3)
      expect(embed.fields.first.name).to eql("Field 1 Name")
      expect(embed.fields.first.value).to eql("Field 1 Value")
      expect(embed.fields.first.inline).to eql(true)
      expect(embed.color).not_to be_nil
    end
  end
end
