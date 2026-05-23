# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::ChannelSend do
  describe ".call" do
    let(:discord_server) { build(:discord_server, channels: %i[general]) }
    let!(:community) { create(:community, discord_server: discord_server) }
    let(:channel) { discord_server.channels.first }

    context "with a Hash message" do
      it "delivers an Embed built from the hash" do
        described_class.call(id: channel.id, message: {description: "hello"})
        ESM.discord_bot.test_outbox.await_size(1)

        delivered = ESM.discord_bot.test_outbox.first.content
        expect(delivered).to be_a(ESM::Embed)
        expect(delivered.description).to eq("hello")
      end
    end

    context "with a JSON-encoded String message" do
      it "parses and delivers as an Embed" do
        described_class.call(id: channel.id, message: {description: "from json"}.to_json)
        ESM.discord_bot.test_outbox.await_size(1)

        delivered = ESM.discord_bot.test_outbox.first.content
        expect(delivered).to be_a(ESM::Embed)
        expect(delivered.description).to eq("from json")
      end
    end

    context "with a plain-text String message" do
      it "delivers the string as-is" do
        described_class.call(id: channel.id, message: "raw notification text")
        ESM.discord_bot.test_outbox.await_size(1)

        expect(ESM.discord_bot.test_outbox.first.content).to eq("raw notification text")
      end
    end

    context "when the channel cannot be found" do
      it "returns nil and delivers nothing" do
        expect(described_class.call(id: Spec::Snowflake.next, message: {description: "x"})).to be_nil
        expect(ESM.discord_bot.test_outbox.size).to eq(0)
      end
    end
  end
end
