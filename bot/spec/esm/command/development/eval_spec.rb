# frozen_string_literal: true

describe ESM::Command::Development::Eval, category: "command" do
  include_context "command"

  let!(:community) { create(:esm_community) }
  let!(:server) { create(:esm_malden, community_id: community.id) }
  let!(:user) { create(:developer) }

  include_examples "validate_command", requires_registration: false

  describe "#execute" do
    context "when the input is a boolean" do
      it "returns a boolean" do
        execute!(arguments: {code: "true"})

        response = ESM::Test.messages.first.content
        expect(response).to eq("Input:\n```ruby\ntrue\n```\nOutput:\n```ruby\ntrue\n```")
      end
    end

    context "when the input is a string" do
      it "returns a string" do
        execute!(arguments: {code: "'test'"})

        response = ESM::Test.messages.first.content
        expect(response).to eq("Input:\n```ruby\n'test'\n```\nOutput:\n```ruby\n\"test\"\n```")
      end
    end

    context "when the input is a math problem" do
      it "returns an integer" do
        execute!(arguments: {code: "2 + 3"})

        response = ESM::Test.messages.first.content
        expect(response).to eq("Input:\n```ruby\n2 + 3\n```\nOutput:\n```ruby\n5\n```")
      end
    end
  end
end
