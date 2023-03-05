# frozen_string_literal: true

describe ESM::Event::DiscordMessageChannelV1 do
  let!(:community) { create(:esm_community) }
  let!(:server) { create(:server, community_id: community.id) }

  def event(params)
    described_class.new(server: server, parameters: params, connection: nil)
  end

  describe "Errors" do
    it "does not send to other community channel" do
      params = OpenStruct.new(channelID: ESM::Community::Secondary::SPAM_CHANNEL, message: "TESTING!")

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eq(1)
      message = ESM::Test.messages.first.second

      expect(message).to eq("**[`ESM_fnc_sendToChannel`]**\nYour Discord Server does not have a channel with ID `#{params.channelID}`. Please provide `ESM_fnc_sendToChannel` a channel ID that belongs to your Discord Server.")
    end

    it "logs and does not send (Malformed)" do
      params = OpenStruct.new(channelID: community.logging_channel_id, message: '["title", "description"]')

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eq(1)
      message = ESM::Test.messages.first.second

      expect(message).to eq("**[`ESM_fnc_sendToChannel`]**\nThe provided message is malformed and unable to be delivered.\nPlease read the API documentation on my website (https://www.esmbot.com/wiki/api) for the correct format.\nThis is the message I attempted to send: ```#{params.message}```")
    end
  end

  describe "Sending String" do
    it "sends" do
      params = OpenStruct.new(channelID: community.logging_channel_id, message: "TESTING!")

      expect { event(params).run! }.not_to raise_error
      expect(ESM::Test.messages.size).to eq(1)
      message = ESM::Test.messages.first

      expect(message.destination.id.to_s).to eq(params.channelID)
      expect(message.content).to eq("**Message from #{server.server_id}**\n#{params.message}")
    end
  end

  describe "Sending Embed" do
    it "sends (Const Color)" do
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
      expect(ESM::Test.messages.size).to eq(1)
      message = ESM::Test.messages.first

      expect(message.destination.id.to_s).to eq(params.channelID)

      embed = message.content
      expect(embed.title).to eq("Title")
      expect(embed.description).to eq("Description")
      expect(embed.fields.size).to eq(3)
      expect(embed.fields.first.name).to eq("Field 1 Name")
      expect(embed.fields.first.value).to eq("Field 1 Value")
      expect(embed.fields.first.inline).to eq(true)
      expect(embed.color).to eq(ESM::Color::Toast::BLUE)
    end

    it "sends (Hex Color)" do
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
      expect(ESM::Test.messages.size).to eq(1)
      message = ESM::Test.messages.first

      expect(message.destination.id.to_s).to eq(params.channelID)

      embed = message.content
      expect(embed.title).to eq("Title")
      expect(embed.description).to eq("Description")
      expect(embed.fields.size).to eq(3)
      expect(embed.fields.first.name).to eq("Field 1 Name")
      expect(embed.fields.first.value).to eq("Field 1 Value")
      expect(embed.fields.first.inline).to eq(true)
      expect(embed.color.upcase).to eq(ESM::Color::BLUE)
    end

    it "sends (Invalid/Random Color)" do
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
      expect(ESM::Test.messages.size).to eq(1)
      message = ESM::Test.messages.first

      expect(message.destination.id.to_s).to eq(params.channelID)

      embed = message.content
      expect(embed.title).to eq("Title")
      expect(embed.description).to eq("Description")
      expect(embed.fields.size).to eq(3)
      expect(embed.fields.first.name).to eq("Field 1 Name")
      expect(embed.fields.first.value).to eq("Field 1 Value")
      expect(embed.fields.first.inline).to eq(true)
      expect(embed.color).not_to be_nil
    end
  end
end
