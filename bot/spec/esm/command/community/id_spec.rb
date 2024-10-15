# frozen_string_literal: true

describe ESM::Command::Community::Id, category: "command" do
  include_context "command"
  include_examples "validate_command", requires_registration: false

  describe "#execute" do
    it "returns the community's ID" do
      execute!

      response = ESM::Test.messages.first.content
      expect(response).not_to be_nil
      expect(response.description).to match(/community id is/i)
      expect(response.fields.size).to eq(1)
      expect(response.fields.first.name).to eq("Want to list all registered servers for this community?")
      expect(response.fields.first.value).to match(/community servers for:/i)
    end
  end
end
