describe ESM::Command::System::Requests, category: "command" do
  let!(:command) { described_class.new }

  it "is valid" do
    expect(command).not_to be_nil
  end

  it "has 0 arguments" do
    expect(command.arguments.size).to eql(0)
  end

  it "has a description" do
    expect(command.description).not_to be_blank
  end

  it "has examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:user) { ESM::Test.user }
    let!(:second_user) { ESM::Test.user }
    let!(:reward_request) { create(:request, requestor_user_id: user.id, requestee_user_id: user.id) }
    let!(:add_request) { create(:request, requestor_user_id: second_user.id, requestee_user_id: user.id, command_name: "add") }

    it "!requests" do
      event = CommandEvent.create(command.statement, user: user, channel_type: :dm)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be(nil)
      expect(embed.title).to eq("Pending Requests")

      expect(embed.description).not_to include(reward_request.requestor.distinct)
      expect(embed.description).to include(
        "reward", reward_request.expires_at.to_s,
        "[Accept]", "~accept #{reward_request.uuid_short}",
        "[Decline]", "~decline #{reward_request.uuid_short}",
        "add", add_request.requestor.distinct, add_request.expires_at.to_s,
        "[Accept]", "~accept #{add_request.uuid_short}",
        "[Decline]", "~decline #{add_request.uuid_short}"
      )
    end
  end
end
