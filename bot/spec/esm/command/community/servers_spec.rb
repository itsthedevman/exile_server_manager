# frozen_string_literal: true

describe ESM::Command::Community::Servers, category: "command" do
  let!(:command) { ESM::Command::Community::Servers.new }

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
    let(:connection) { WebsocketClient.new(server) }

    it "should return no servers" do
      community.servers.destroy_all

      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /i was unable to find any registered servers/i)
    end

    it "should not crash on empty server name" do
      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      server.server_name = nil
      expect { command.execute(event) }.not_to raise_error

      server.server_name = nil
      command.current_cooldown.reset!
      expect { command.execute(event) }.not_to raise_error
    end

    it "should return one offline server" do
      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.title).to eql(server.server_name)
      expect(embed.description).to eql(I18n.t("commands.servers.offline"))
      expect(embed.fields.size).to eql(3)
      expect(embed.fields.first.name).to eql(I18n.t(:server_id))
      expect(embed.fields.first.value).to eql("```#{server.server_id}```")
      expect(embed.fields.second.name).to eql(I18n.t(:ip))
      expect(embed.fields.second.value).to eql("```#{server.server_ip}```")
      expect(embed.fields.third.name).to eql(I18n.t(:port))
      expect(embed.fields.third.value).to eql("```#{server.server_port}```")
    end

    it "should return one online server" do
      connection

      wait_for { connection.connected? }.to be(true)

      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second
      server.reload

      expect(embed.title).to eql(server.server_name)
      expect(embed.fields.size).to eql(5)
      expect(embed.fields.first.name).to eql(I18n.t(:server_id))
      expect(embed.fields.first.value).to eql("```#{server.server_id}```")
      expect(embed.fields.second.name).to eql(I18n.t(:ip))
      expect(embed.fields.second.value).to eql("```#{server.server_ip}```")
      expect(embed.fields.third.name).to eql(I18n.t(:port))
      expect(embed.fields.third.value).to eql("```#{server.server_port}```")
      expect(embed.fields.fourth.name).to eql(I18n.t("commands.server.online_for"))
      expect(embed.fields.fourth.value).to eql("```#{server.uptime}```")
      expect(embed.fields.fifth.name).to eql(I18n.t("commands.server.restart_in"))
      expect(embed.fields.fifth.value).to eql("```#{server.time_left_before_restart}```")

      connection.disconnect!
    end
  end
end
