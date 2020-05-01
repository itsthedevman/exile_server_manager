# frozen_string_literal: true

describe ESM::Command::Server::Me, category: "command" do
  let!(:command) { ESM::Command::Server::Me.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
    expect(command.arguments.size).to eql(1)
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

    it "should return" do
      request = nil
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages).not_to be_blank

      embed = ESM::Test.messages.first.second
      server_response = request.command.response

      expect(embed.title).to match(/.+'s stats on `#{server.server_id}`/)
      expect(embed.fields.size).to be >= 3

      if server_response.territories.present?
        expect(embed.fields.size).to eql(4)
        expect(embed.fields[3].name).to eql("Territories")
        expect(embed.fields[3].value).not_to be_blank
      end
    end
  end
end
