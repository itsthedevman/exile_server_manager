# frozen_string_literal: true

describe "ESMs_util_embed_create", requires_connection: true, v2: true do
  include_context "connection"

  it "returns the embed" do
    response = execute_sqf!(
      <<~SQF
        [["title", "This is the title"], ["description", "This is a description"]] call ESMs_util_embed_create
      SQF
    )

    expect(response).not_to be_nil

    hash = ESM::Arma::HashMap.new(response.data.result)
    expect(hash).not_to be_nil

    expect(hash).to include(
      "title" => "This is the title",
      "description" => "This is a description"
    )
  end

  it "skips invalid keys" do
    response = execute_sqf!(
      # TYPO ON PURPOSE
      <<~SQF
        [["title", "This is the title"], ["descrtion", "This is a description"]] call ESMs_util_embed_create
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["title", "This is the title"]])
  end

  it "skips invalid values" do
    response = execute_sqf!(
      <<~SQF
        [["title", nil], ["description", "This is a description"]] call ESMs_util_embed_create
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["description", "This is a description"]])
  end
end
