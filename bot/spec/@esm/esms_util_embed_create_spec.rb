# frozen_string_literal: true

describe "ESMs_util_embed_create", :requires_connection, v2: true do
  include_context "connection"

  context "when the embed data is valid" do
    it "returns the embed" do
      response = execute_sqf!(
        <<~SQF
          [["title", "This is the title"], ["description", "This is a description"]] call ESMs_util_embed_create
        SQF
      )

      expect(response).not_to be_nil

      hash = ESM::Arma::HashMap.new(response)
      expect(hash).not_to be_nil

      expect(hash).to include(
        "title" => "This is the title",
        "description" => "This is a description"
      )
    end
  end

  context "when invalid keys are provided" do
    it "skips them" do
      response = execute_sqf!(
        # TYPO ON PURPOSE
        <<~SQF
          [["title", "This is the title"], ["descrtion", "This is a description"]] call ESMs_util_embed_create
        SQF
      )

      expect(response).to eq([["title", "This is the title"]])
    end
  end

  context "when invalid values are provided to valid keys" do
    it "skips them" do
      response = execute_sqf!(
        <<~SQF
          [["title", nil], ["description", "This is a description"]] call ESMs_util_embed_create
        SQF
      )

      expect(response).to eq([["description", "This is a description"]])
    end
  end
end
