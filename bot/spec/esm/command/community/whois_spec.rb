# frozen_string_literal: true

describe ESM::Command::Community::Whois, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    before do
      ESM::Test.skip_cooldown = true
      grant_command_access!(community, "whois")
    end

    context "when the target is a mention" do
      it "returns information about the user" do
        execute!(arguments: {target: user.mention})

        response = latest_message
        expect(response).not_to be_nil
        expect(response.fields).not_to be_empty
      end
    end

    context "when the target is a registered steam uid" do
      it "returns information about the registered user" do
        execute!(arguments: {target: user.steam_uid})

        response = latest_message
        expect(response).not_to be_nil
        expect(response.fields).not_to be_empty
      end
    end

    context "returns information about the user" do
      it "should run (discord id)" do
        execute!(arguments: {target: user.discord_id})

        response = latest_message
        expect(response).not_to be_nil
        expect(response.fields).not_to be_empty
      end
    end

    context "when the target is not registered" do
      before do
        user.update!(steam_uid: "")
      end

      it "returns information about the discord user" do
        execute!(arguments: {target: user.mention})

        response = latest_message
        expect(response).not_to be_nil
        expect(response.fields).not_to be_empty
      end
    end

    context "when the target is an unregistered steam uid" do
      it "returns information about the steam user" do
        execute!(arguments: {target: ESM::Test.steam_uid})

        response = latest_message
        expect(response).not_to be_nil
        expect(response.fields).not_to be_empty
      end
    end

    context "when the target is not a member of the discord server" do
      it "raises an exception" do
        # Exile Server Manager Bot ID
        expect { execute!(arguments: {target: "417847994197737482"}) }.to raise_error(ESM::Exception::CheckFailure)
      end
    end
  end
end
