# frozen_string_literal: true

describe ESM::Message, v2: true do
  let(:community) { ESM::Test.community }
  let(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server(for: community) }

  let(:input) do
    {
      id: SecureRandom.uuid,
      type: :call,
      data: {
        array: [false, true, "2", "3.0"],
        date_time: ESM::Time.current,
        date: Time.zone.today,
        hash_map: ESM::Arma::HashMap.from(key_0: false, key_1: true),
        integer: "1",
        rhash: {foo: "bar"},
        string: "string"
      },
      metadata: {},
      errors: []
    }.to_json.to_h
  end

  let(:input_message) do
    described_class.from_hash(input)
  end

  describe ".from_string" do
    it "parses" do
      message = described_class.from_string(input.to_json)

      expect(message.id).to eq(input_message.id)
      expect(message.type).to eq(input_message.type)
      expect(message.errors).to eq(input_message.errors)

      # Data
      expect(message.data.string).to eq(input_message.data.string)
      expect(message.data.integer).to eq(input_message.data.integer)
      expect(message.data.rhash).to eq(input_message.data.rhash)
      expect(message.data.array).to eq(input_message.data.array)
      expect(message.data.hash_map).to eq(input_message.data.hash_map)
      expect(message.data.date_time).to eq(input_message.data.date_time)
      expect(message.data.date).to eq(input_message.data.date)
    end
  end

  describe "#initialize" do
    it "requires a type" do
      expect { described_class.new }.not_to raise_error
    end

    it "defaults to empty" do
      message = described_class.new
      expect(message.type).to eq(:call)
      expect(message.data.to_h).to eq({})
      expect(message.metadata.to_h).to eq({})
    end
  end

  describe "#to_s/#to_json" do
    it "is valid json" do
      expect(input_message.to_s).to eq(input.to_json)
    end
  end

  describe "#error_messages" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    let(:message) do
      described_class.new.set_data(foo: "bar")
    end

    before do
      command.instance_variable_set(:@current_user, user)
      command.instance_variable_set(:@current_channel, ESM::Test.channel(in: community))
      message.set_metadata(player: user, server_id: "baz")
    end

    it "handles codes" do
      message.add_error(:code, "test")

      expect(message.error_messages).to eq([
        # See config/locales/exceptions/en.yml -> exceptions.extension.test
        "#{user.mention} | #{message.id} | #{message.type} | #{message.data.foo} | #{message.metadata.server_id} | #{user.discord_mention}"
      ])
    end

    it "handles messages" do
      message.add_error("message", "Hello World")

      expect(message.error_messages).to eq(["Hello World"])
    end
  end
end
