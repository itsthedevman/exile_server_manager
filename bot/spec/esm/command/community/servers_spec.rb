# frozen_string_literal: true

describe ESM::Command::Community::Servers, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }
    let(:connection) { WebsocketClient.new(server) }

    it "returns no servers" do
      community.servers.destroy_all

      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /i was unable to find any registered servers/i)
    end

    it "does not crash on empty server name" do
      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      server.server_name = nil
      expect { command.execute(event) }.not_to raise_error

      server.server_name = nil
      command.current_cooldown.reset!
      expect { command.execute(event) }.not_to raise_error
    end

    it "returns one offline server" do
      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.title).to eq(server.server_name)
      expect(embed.description).to eq(I18n.t("commands.servers.offline"))
      expect(embed.fields.size).to eq(3)
      expect(embed.fields.first.name).to eq(I18n.t(:server_id))
      expect(embed.fields.first.value).to eq("```#{server.server_id}```")
      expect(embed.fields.second.name).to eq(I18n.t(:ip))
      expect(embed.fields.second.value).to eq("```#{server.server_ip}```")
      expect(embed.fields.third.name).to eq(I18n.t(:port))
      expect(embed.fields.third.value).to eq("```#{server.server_port}```")
    end

    it "returns one online server" do
      connection

      wait_for { connection.connected? }.to be(true)

      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second
      server.reload

      expect(embed.title).to eq(server.server_name)
      expect(embed.fields.size).to eq(5)
      expect(embed.fields.first.name).to eq(I18n.t(:server_id))
      expect(embed.fields.first.value).to eq("```#{server.server_id}```")
      expect(embed.fields.second.name).to eq(I18n.t(:ip))
      expect(embed.fields.second.value).to eq("```#{server.server_ip}```")
      expect(embed.fields.third.name).to eq(I18n.t(:port))
      expect(embed.fields.third.value).to eq("```#{server.server_port}```")
      expect(embed.fields.fourth.name).to eq(I18n.t("commands.server.online_for"))
      expect(embed.fields.fourth.value).to eq("```#{server.uptime}```")
      expect(embed.fields.fifth.name).to eq(I18n.t("commands.server.restart_in"))
      expect(embed.fields.fifth.value).to eq("```#{server.time_left_before_restart}```")

      connection.disconnect!
    end

    it "does not show private servers" do
      private_server = ESM::Test.server
      private_server.update!(server_visibility: :private)

      command_statement = command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eq(1)
    end
  end
end
