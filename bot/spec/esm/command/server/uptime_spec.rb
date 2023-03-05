# frozen_string_literal: true

describe ESM::Command::Server::Uptime, category: "command" do
  let!(:command) { ESM::Command::Server::Uptime.new }

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
    let!(:user) { ESM::Test.user }
    let!(:wsc) { WebsocketClient.new(server) }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "!uptime server_id" do
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error

      # Attempt to freeze the uptime
      server.reload
      uptime = server.uptime

      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/`#{server.server_id}` has been online for #{uptime}/i)
    end
  end
end
