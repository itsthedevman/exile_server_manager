# frozen_string_literal: true

describe ESM::Command::Community::Server, category: "command" do
  let!(:command) { ESM::Command::Community::Server.new }

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
    let(:connection) { ESM::Websocket.connections[server.server_id] }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should return invalid server" do
      command_statement = command.statement(server_id: "esm_test")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "should return an embed" do
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error
      response = ESM::Test.messages.first.second

      # Reload because the server updates when the WSC connects
      server.reload
      expect(response).not_to be_nil
      expect(response.title).to eq(server.server_name)
      expect(response.description).to be_nil
      expect(response.fields).not_to be_empty
      expect(response.fields.first.name).to eq("Server ID")
      expect(response.fields.first.value).to eq("```#{server.server_id}```")
      expect(response.fields.second.name).to eq("IP")
      expect(response.fields.second.value).to eq("```#{server.server_ip}```")
      expect(response.fields.third.name).to eq("Port")
      expect(response.fields.third.value).to eq("```#{server.server_port}```")
      expect(response.fields.fourth.name).to eq("✅ Online for")
      expect(response.fields.fifth.name).to eq("⏰ Next restart in")
    end
  end
end
