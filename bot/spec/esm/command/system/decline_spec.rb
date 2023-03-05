# frozen_string_literal: true

describe ESM::Command::System::Decline, category: "command" do
  let!(:command) { ESM::Command::System::Decline.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
    expect(command.arguments.size).to eq(1)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user_1) { ESM::Test.user }
    let!(:user_2) { ESM::Test.user }

    let!(:request) do
      channel_id = [ESM::Community::ESM::SPAM_CHANNEL, ESM::Community::Secondary::SPAM_CHANNEL].sample

      create(
        :request,
        requestor_user_id: user_1.id,
        requestee_user_id: user_2.id,
        requested_from_channel_id: channel_id,
        command_name: "id"
      )
    end

    it "should run (Valid UUID)" do
      command_statement = command.statement(uuid: request.uuid_short)
      event = CommandEvent.create(command_statement, user: user_2, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be(nil)
      expect(ESM::Request.all.size).to eq(0)
    end

    it "should run (Invalid UUID)" do
      # The uuid is valid, but the user_1 is not the who the request is for
      command_statement = command.statement(uuid: request.uuid_short)
      event = CommandEvent.create(command_statement, user: user_1, channel_type: :dm)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /unable to find a request/i)
    end
  end
end
