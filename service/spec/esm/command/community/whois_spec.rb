# frozen_string_literal: true

describe ESM::Command::Community::Whois, category: "command" do
  include_context "command"
  include_examples "validate_command", requires_registration: false

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
      it "runs (discord id)" do
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
        execute!(arguments: {target: Faker::Steam.uid})

        response = latest_message
        expect(response).not_to be_nil
        expect(response.fields).not_to be_empty
      end
    end

    # The target has to be a real ESM::User who simply is not in this community's Discord. An arbitrary Discord ID
    # never resolves to a user at all, so it fails target resolution long before it reaches the membership check.
    context "when the target is not a member of the discord server" do
      let(:outsider) { create(:user) }

      # Asserting on the key rather than the copy identifies which failure this is (several render the caller's
      # mention, so matching the mention alone would accept the wrong one) and survives a rewording. Checking the
      # description separately is what catches a missing translation.
      it "denies access" do
        expect { execute!(arguments: {target: outsider.discord_id}) }
          .to raise_error(ESM::Exception::CheckFailure) do |error|
            expect(error.key).to eq("commands.whois.errors.access_denied")
            expect(error.to_embed.description).to include(user.mention)
          end
      end
    end
  end

  describe "#on_website_execute" do
    subject(:result) { execute_sync!(arguments: {target: target}) }

    before do
      ESM::Test.skip_cooldown = true
      grant_command_access!(community, "whois")
    end

    context "when the target is a member of the community's Discord" do
      let(:target) { second_user.discord_id }

      it "returns both Steam and Discord information" do
        expect(result[:steam]).to be_present
        expect(result[:discord][:id]).to eq(second_user.discord_id)
      end
    end

    # The caller handed over the identifier, so Steam discloses nothing new and is never gated. Discord is the only
    # thing the membership check ever protected, and it stays protected.
    context "when the target is registered but not a member of the community's Discord" do
      let(:target) { create(:user).discord_id }

      it "returns Steam information and withholds Discord information" do
        expect(result[:steam]).to be_present
        expect(result).not_to have_key(:discord)
      end
    end

    # A bare Steam UID has no ESM account behind it, so there is no Discord identity to withhold in the first place.
    context "when the target is an unregistered Steam UID" do
      let(:target) { Faker::Steam.uid }

      it "returns Steam information and withholds Discord information" do
        expect(result[:steam]).to be_present
        expect(result).not_to have_key(:discord)
      end
    end
  end
end
