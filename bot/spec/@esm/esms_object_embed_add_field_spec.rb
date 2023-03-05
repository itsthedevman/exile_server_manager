# frozen_string_literal: true

describe "ESMs_object_embed_addField", requires_connection: true, v2: true do
  include_context "connection"

  it "returns adds a field to the embed" do
    response = execute_sqf!(
      <<~SQF
        private _embed = [["title", "This is the title"], ["description", "This is a description"]] call ESMs_object_embed_create;

        [_embed, "Field name", "Field value"] call ESMs_object_embed_addField;

        _embed
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["fields", [[["name", "Field name"], ["inline", false], ["value", "Field value"]]]], ["description", "This is a description"], ["title", "This is the title"]])
  end
end
