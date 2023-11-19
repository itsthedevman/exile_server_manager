# frozen_string_literal: true

describe ESM::Command::My::Requests, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    let!(:reward_request) do
      create(:request, requestor_user_id: user.id, requestee_user_id: user.id)
    end

    let!(:add_request) do
      create(:request, requestor_user_id: second_user.id, requestee_user_id: user.id, command_name: "add")
    end

    context "when the user has requests" do
      it "returns a list of them" do
        execute!(channel_type: :dm)

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be(nil)
        expect(embed.title).to eq("Pending Requests")

        expect(embed.description).not_to include(reward_request.requestor.distinct)
        expect(embed.description).to include(
          "reward", reward_request.expires_at.to_s,
          "[Accept]", "/requests accept uuid:#{reward_request.uuid_short}",
          "[Decline]", "/requests decline uuid:#{reward_request.uuid_short}",
          "add", add_request.requestor.distinct, add_request.expires_at.to_s,
          "[Accept]", "/requests accept uuid:#{add_request.uuid_short}",
          "[Decline]", "/requests decline uuid:#{add_request.uuid_short}"
        )
      end
    end
  end
end
