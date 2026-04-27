# frozen_string_literal: true

describe ESM::Command::Base::Helpers do
  describe "#argument?" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::ArgumentDisplayName }
    end

    context "when the argument exists and the argument's name is given" do
      it "returns true" do
        expect(command.argument?(:argument_name)).to be(true)
      end
    end

    context "when the argument exists and the argument's display name is given" do
      it "returns true" do
        expect(command.argument?(:display_name)).to be(true)
      end
    end

    context "when the argument does not exists" do
      it "returns false" do
        expect(command.argument?(:does_not_exist)).to be(false)
      end
    end
  end

  describe "#embed_from_message!", requires_connection: true do
    include_context "command" do
      let!(:command) do
        ESM::Command::Test::ServerCommand.new(
          user: user.discord_user,
          arguments: {server_id: server.server_id},
          channel: ESM::Test.channel(in: community)
        )
      end
    end

    include_context "connection"

    subject(:embed_from_message) { command.embed_from_message!(ESM::Message.new.set_data(**data)) }

    context "when the data is valid" do
      let(:data) { {title: "some title"} }

      it "returns an embed" do
        expect(embed_from_message).to be_instance_of(ESM::Embed)
      end
    end

    context "when the data is empty" do
      let(:data) { {} }

      it "sends a message to the server and raises CheckFailure" do
        expect(server.connection).to receive(:send_error).and_call_original

        expect { embed_from_message }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match("please reach out to the server owners")
        end
      end
    end

    context "when the data contains extra data" do
      let(:data) { {description: "A description", foo: "bar"} }

      it "sends a message to the server and raises CheckFailure" do
        expect(server.connection).to receive(:send_error).and_call_original

        expect { embed_from_message }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match("please reach out to the server owners")
        end
      end
    end
  end
end
