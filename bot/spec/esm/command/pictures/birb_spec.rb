# frozen_string_literal: true

describe ESM::Command::Pictures::Birb, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    it "returns a picture" do
      execute!

      response = ESM::Test.messages.second.content
      expect(response).not_to be_nil
      expect(response).to match(/\.jpg$|\.png$|\.gif$|\.jpeg$/i)
    end
  end
end
