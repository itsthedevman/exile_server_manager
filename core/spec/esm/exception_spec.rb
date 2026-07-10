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
