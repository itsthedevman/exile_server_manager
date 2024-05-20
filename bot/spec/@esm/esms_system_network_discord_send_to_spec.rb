# frozen_string_literal: true

describe "ESMs_system_network_discord_send_to", :requires_connection, v2: true do
  include_context "connection"

  context "when the a channel ID and a string message is provided" do
    it "sends the message to the channel" do
      channel = server.community.discord_server.channels.sample
      execute_sqf!(
        <<~SQF
          ["#{channel.id}", "This is a message"] call ESMs_system_network_discord_send_to;
        SQF
      )

      wait_for { ESM::Test.messages }.not_to be_empty

      content = ESM::Test.messages.first.content
      expect(content).to eq("*Sent from `#{server.server_id}`*\nThis is a message")
    end
  end

  context "when the a channel name and embed message is provided" do
    it "finds the channel, converts the data to an embed, and sends it to the channel" do
      channel = server.community.discord_server.channels.sample
      execute_sqf!(
        <<~SQF
          private _embed = [["title", "This is a title"], ["description", "This is a description"]] call ESMs_util_embed_create;
          [_embed, "Field name", "Field value"] call ESMs_util_embed_addField;
          ["#{channel.name}", _embed] call ESMs_system_network_discord_send_to;
        SQF
      )

      wait_for { ESM::Test.messages }.not_to be_empty

      content = ESM::Test.messages.first.content
      expect(content).to be_kind_of(ESM::Embed)

      expect(content.title).to eq("This is a title")
      expect(content.description).to eq("This is a description")

      expect(content.fields.size).to eq(1)

      field = content.fields.first
      expect(field.name).to eq("Field name")
      expect(field.value).to eq("Field value")
      expect(field.inline).to eq(false)

      sent_to_channel = ESM::Test.messages.first.destination
      expect(sent_to_channel.id).to eq(channel.id)
    end
  end
end
