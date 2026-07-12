# frozen_string_literal: true

RSpec.describe ESM::Exception::ApplicationError do
  describe "#to_content" do
    context "when the data is a String" do
      subject(:error) { described_class.new("Something broke") }

      it "returns the string unchanged" do
        expect(error.to_content).to eq("Something broke")
      end
    end

    context "when the data is an Array" do
      subject(:error) { described_class.new(["First line", "Second line"]) }

      it "joins the entries with newlines" do
        expect(error.to_content).to eq("First line\nSecond line")
      end
    end

    context "when the data is a Hash" do
      subject(:error) { described_class.new({description: "The reason", title: "Nope"}) }

      it "returns the description line" do
        expect(error.to_content).to eq("The reason")
      end

      context "and the keys are strings" do
        subject(:error) { described_class.new({"description" => "The reason"}) }

        it "still returns the description line" do
          expect(error.to_content).to eq("The reason")
        end
      end
    end
  end

  describe "#to_embed" do
    context "when the data is blank" do
      subject(:error) { described_class.new("") }

      it "returns the raw data rather than building an embed" do
        expect(error.to_embed).to eq("")
      end
    end

    context "when the data is a String" do
      subject(:error) { described_class.new("Something broke") }

      it "builds an error embed described by the content" do
        expect(error.to_embed).to be_a(ESM::Embed).and have_attributes(description: "Something broke")
      end
    end

    context "when the data is an Array" do
      subject(:error) { described_class.new(["First line", "Second line"]) }

      it "builds an error embed from the joined content" do
        expect(error.to_embed).to be_a(ESM::Embed).and have_attributes(description: "First line\nSecond line")
      end
    end

    context "when the data is a Hash" do
      subject(:error) { described_class.new({description: "The reason", color: "red"}) }

      it "rebuilds the embed from the hash" do
        expect(error.to_embed).to be_a(ESM::Embed).and have_attributes(description: "The reason")
      end
    end
  end

  describe ESM::Exception::ExtensionError do
    subject(:error) { described_class.new(["Not enough poptabs", "Try again"]) }

    it "inherits the base content and embed behavior" do
      expect(error.to_content).to eq("Not enough poptabs\nTry again")
      expect(error.to_embed).to have_attributes(description: "Not enough poptabs\nTry again")
    end
  end
end

RSpec.describe ESM::Exception::CheckFailure do
  let(:user) { ESM::User.new(discord_id: "137", discord_username: "Bryan") }

  describe "a keyed failure" do
    subject(:error) do
      described_class.new(key: "command_errors.on_cooldown_time_left", user: user, time_left: "8 seconds")
    end

    it "renders #message as the Discord copy, projecting the user to a mention" do
      expect(error.message).to include("<@137>").and include("8 seconds")
    end

    it "builds #to_embed from the rendered copy" do
      expect(error.to_embed).to be_a(ESM::Embed).and have_attributes(description: a_string_including("<@137>"))
    end

    it "projects the user through a caller-supplied projector in #render" do
      rendered = error.render(&:username)

      expect(rendered).to include("Bryan")
      expect(rendered).not_to include("<@137>")
    end
  end

  describe "a keyed failure with a _web variant" do
    subject(:error) do
      described_class.new(key: "command_errors.not_registered", user: user, full_username: "Bryan#0001")
    end

    it "prefers the suffixed key when it exists" do
      expect(error.render(suffix: "_web", &:username)).to include("before you can run commands")
    end

    it "falls back to the base key when no suffix is requested" do
      expect(error.render(&:username)).to include("with your Discord account")
    end
  end

  describe "an Ephemeral (unregistered) target in the details" do
    subject(:error) do
      described_class.new(
        key: "command_errors.target_not_registered",
        user: user,
        target_user: ESM::User::Ephemeral.new("76561199060562957")
      )
    end

    it "projects the Ephemeral just like a registered user" do
      expect(error.message).to include("76561199060562957")
    end
  end

  describe "a literal (block-form) failure" do
    subject(:error) { described_class.new("Something specific went wrong") }

    it "returns the literal text for #message and #to_content" do
      expect(error.message).to eq("Something specific went wrong")
      expect(error.to_content).to eq("Something specific went wrong")
    end

    it "wraps the literal text in #to_embed" do
      expect(error.to_embed).to have_attributes(description: "Something specific went wrong")
    end
  end
end
