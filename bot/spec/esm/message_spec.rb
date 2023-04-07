# frozen_string_literal: true

describe ESM::Message, v2: true do
  let(:community) { ESM::Test.community }
  let(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server }

  let(:input) do
    {
      id: SecureRandom.uuid,
      type: "test",
      data: {
        type: "test_mapping",
        content: {
          # Order matters!
          array: [false, true, "2", "3.0"],
          date_time: ESM::Time.current,
          date: Date.today,
          hash_map: ESM::Arma::HashMap.from(key_0: false, key_1: true),
          integer: "1",
          rhash: {foo: "bar"},
          string: "string"
        }
      },
      metadata: {
        type: "empty",
        content: {}
      },
      errors: []
    }
  end

  let(:input_message) do
    described_class.from_hash(input)
  end

  describe ".from_string" do
    it "parses" do
      message = described_class.from_string(input.to_json)

      expect(message.id).to eq(input_message.id)
      expect(message.type).to eq(input_message.type)
      expect(message.data_type).to eq(input_message.data_type)
      expect(message.metadata_type).to eq(input_message.metadata_type)
      expect(message.errors).to eq(input_message.errors)

      # Data
      expect(message.data.string).to eq(input_message.data.string)
      expect(message.data.integer).to eq(input_message.data.integer)
      expect(message.data.rhash).to eq(input_message.data.rhash)
      expect(message.data.array).to eq(input_message.data.array)
      expect(message.data.hash_map).to eq(input_message.data.hash_map)
      expect(message.data.date_time.to_s).to eq(input_message.data.date_time.to_s)
      expect(message.data.date).to eq(input_message.data.date)
    end
  end

  describe "#initialize" do
    it "requires a type" do
      expect { described_class.test }.not_to raise_error
    end

    it "defaults to empty" do
      message = described_class.event
      expect(message.type).to eq("event")
      expect(message.data_type).to eq("empty")
      expect(message.data.to_h).to eq({})
      expect(message.metadata_type).to eq("empty")
      expect(message.metadata.to_h).to eq({})
    end

    it "converts to strings" do
      message = described_class.test
      expect(message.type).to eq("test")
      expect(message.data_type).to eq("empty")
      expect(message.metadata_type).to eq("empty")
    end
  end

  describe "#to_s/#to_json" do
    it "is valid json" do
      expect(input_message.to_s).to eq(input.to_json)
    end
  end

  describe "#on_error" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    let(:message) do
      ESM::Message.event
        .set_data(:data_test, {foo: "bar"})
        .set_metadata(:metadata_test, {bar: "baz"})
    end

    before do
      command.instance_variable_set(:@current_user, user.discord_user)
      command.instance_variable_set(:@current_channel, ESM::Test.channel)

      message.add_attribute(:command, command)
    end

    it "handles codes" do
      message.add_error(:code, "test").send(:on_error, nil)
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.shift&.content
      expect(embed).not_to be_nil

      # See config/locales/exceptions/en.yml -> exceptions.extension.test
      expect(embed.description).to eq("#{user.mention} | #{message.id} | #{message.type} | #{message.data_type} | #{message.metadata_type} | #{message.data.foo} | #{message.metadata.bar}")
    end

    it "handles messages" do
      message.add_error("message", "Hello World").send(:on_error, nil)
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.shift&.content
      expect(embed).not_to be_nil

      expect(embed.description).to eq("Hello World")
    end
  end
end
