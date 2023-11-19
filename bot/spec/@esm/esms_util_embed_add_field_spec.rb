# frozen_string_literal: true

describe "ESMs_util_embed_addField", :requires_connection, v2: true do
  include_context "connection"

  it "returns adds a field to the embed" do
    response = execute_sqf!(
      <<~SQF
        private _embed = [["title", "This is the title"], ["description", "This is a description"]] call ESMs_util_embed_create;

        [_embed, "Field name", "Field value"] call ESMs_util_embed_addField;

        _embed
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["fields", [[["name", "Field name"], ["inline", false], ["value", "Field value"]]]], ["description", "This is a description"], ["title", "This is the title"]])
  end
end
