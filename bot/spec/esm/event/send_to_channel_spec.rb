# frozen_string_literal: true

describe ESM::Event::SendToChannel, :requires_connection, v2: true do
  include_context "connection"

  let!(:channel) { ESM::Test.channel(in: community) }

  before do
    server.update!(server_version: "2.0.0")
    community.update!(logging_channel_id: channel.id)
  end

  context "when the data is valid" do
    it "send the message" do
      inbound_message = ESM::Message.new
        .set_type(:call)
        .set_data(
          function_name: "send_to_channel",
          id: channel.id.to_s,
          content: Faker::String.random
        )

      described_class.new(server, inbound_message).run!
      wait_for { ESM::Test.messages }.not_to be_blank

      message = ESM::Test.messages.first
      expect(message).not_to be_nil
      expect(message.content).to eq("*Sent from `#{server.server_id}`*\n#{inbound_message.data.content}")
    end
  end

  context "when the context is embed data" do
    it "builds and sends the embed" do
      embed_hash = ESM::Arma::HashMap.new(
        title: Faker::String.random,
        description: Faker::String.random,
        color: ESM::Color.random,
        fields: [
          {name: Faker::String.random, value: Faker::String.random, inline: true}
        ]
      )

      inbound_message = ESM::Message.new
        .set_type(:call)
        .set_data(
          function_name: "send_to_channel",
          id: channel.id.to_s,
          content: embed_hash.to_json
        )

      described_class.new(server, inbound_message).run!
      wait_for { ESM::Test.messages }.not_to be_blank

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      embed = message.content
      expect(embed.title).to eq(embed_hash[:title])
      expect(embed.description).to eq(embed_hash[:description])
      expect(embed.color).to eq(embed_hash[:color])
      expect(embed.fields.size).to eq(1)

      embed_field = embed.fields.first
      hash_field = embed_hash[:fields].first

      expect(embed_field).not_to be_nil
      expect(hash_field).not_to be_nil

      expect(embed_field.name).to eq(hash_field[:name])
      expect(embed_field.value).to eq(hash_field[:value])
      expect(embed_field.inline).to eq(hash_field[:inline])
    end
  end

  context "when the channel does not exist in the community" do
    it "only allows sending messages to that community's discord channels" do
      inbound_message = ESM::Message.new
        .set_type(:call)
        .set_data(
          function_name: "send_to_channel",
          id: "THIS CHANNEL CANNOT EXIST",
          content: Faker::String.random
        )

      described_class.new(server, inbound_message).run!
      wait_for { ESM::Test.messages }.not_to be_blank

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      expect(message.content).to match(%r{hi there!\nyour server `#{server.server_id}` has encountered an error that requires your attention. please open `esm.log` located in \[`@esm/logs/`\]\(or the pre-configured log file path\) and search for `[\w-]{36}` for the full error.}i)
    end
  end

  context "when the embed data contains hash values" do
    it "converts values to a formatted string" do
      embed_hash = ESM::Arma::HashMap.new(
        fields: [
          {name: "n/a", value: '[["discord_id", "discord_id_1"],["steam_uid", "steam_uid_2"],["user_name", "user_name_3"]]', inline: false}
        ]
      )

      inbound_message = ESM::Message.new
        .set_type(:call)
        .set_data(
          function_name: "send_to_channel",
          id: channel.id.to_s,
          content: embed_hash.to_json
        )

      described_class.new(server, inbound_message).run!
      wait_for { ESM::Test.messages }.not_to be_blank

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      embed = message.content
      expect(embed.fields.size).to eq(1)

      embed_field = embed.fields.first
      hash_field = embed_hash[:fields].first

      expect(embed_field).not_to be_nil
      expect(hash_field).not_to be_nil

      expect(embed_field.value).to eq("**Discord ID:** discord_id_1\n**Steam UID:** steam_uid_2\n**User name:** user_name_3")
    end
  end
end
