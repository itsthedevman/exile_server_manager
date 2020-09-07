# frozen_string_literal: true

describe ESM::Command::Server::Info, category: "command" do
  let!(:command) { ESM::Command::Server::Info.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 3 argument" do
    expect(command.arguments.size).to eql(3)
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

    # If you need to connect to a server
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    def build_fields(values)
      output = []
      temp = ""
      values.each do |value|
        value += "\n"

        if temp.size + value.size >= ESM::Embed::Limit::FIELD_VALUE_LENGTH_MAX
          output << temp
          temp = ""
        end

        temp += value
      end
      output << temp
    end

    before :each do
      # Allow user to use this command
      community.command_configurations.where(command_name: "info").update(whitelist_enabled: false)

      wait_for { wsc.connected? }.to be(true)

      # IMPORTANT!
      # If we don't reload the server model after WSC connection, the server settings will be wrong!
      server.reload
    end

    after :each do
      wsc.disconnect!
    end

    it "!info <server_id> <tag> (Player/Alive)" do
      wsc.flags.PLAYER_ALIVE = true
      command_statement = command.statement(server_id: server.server_id, target: user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.title).to match(/stats on `#{server.server_id}`/i)

      field = embed.fields.first
      expect(field.name).to match(/general/i)
      expect(field.value).to match(/health.+%.+hunger.+%.+thirst.+%/im)

      field = embed.fields.second
      expect(field.name).to match(/currency/i)
      expect(field.value).to match(/money.+poptabs.+locker.+poptabs.+respect.+/im)

      field = embed.fields.third
      expect(field.name).to match(/scoreboard/i)
      expect(field.value).to match(/kills.+deaths.+kd ratio.+/im)
    end

    it "!info <server_id> <steam_uid> (Player/Dead)" do
      command_statement = command.statement(server_id: server.server_id, target: user.steam_uid)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.title).to match(/stats on `#{server.server_id}`/i)

      field = embed.fields.first
      expect(field.name).to match(/general/i)
      expect(field.value).to match(/health.+%.+hunger.+%.+thirst.+%/im)

      field = embed.fields.second
      expect(field.name).to match(/currency/i)
      expect(field.value).to match(/money.+poptabs.+locker.+poptabs.+respect.+/im)

      field = embed.fields.third
      expect(field.name).to match(/scoreboard/i)
      expect(field.value).to match(/kills.+deaths.+kd ratio.+/im)
    end

    it "!info <server_id> <territory_id> (Territory)" do
      command_statement = command.statement(server_id: server.server_id, territory_id: "12345")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      territory = ESM::Arma::Territory.new(server: server, territory: response)

      expect(embed.title).to eql("Territory \"#{territory.name}\"")
      expect(embed.thumbnail.url).to eql(territory.flag_path)
      expect(embed.color).to eql(territory.status_color)
      expect(embed.description).to eql(territory.payment_reminder_message)

      field_info = [
        { name: "Territory ID", value: "```#{territory.id}```" },
        { name: "Flag Status", value: "```#{territory.flag_status}```" },
        { name: "Next Due Date", value: "```#{territory.next_due_date.strftime(ESM::Time::Format::TIME)}```" },
        { name: "Last Paid", value: "```#{territory.last_paid_at.strftime(ESM::Time::Format::TIME)}```" },
        { name: "Price to renew protection", value: territory.renew_price },
        { value: "__Current Territory Stats__" },
        { name: "Level", value: territory.level },
        { name: "Radius", value: "#{territory.radius}m" },
        { name: "Current / Max Objects", value: "#{territory.object_count}/#{territory.max_object_count}" }
      ]

      if territory.upgradeable?
        field_info.push(
          { value: "__Next Territory Stats__" },
          { name: "Level", value: territory.upgrade_level },
          { name: "Radius", value: "#{territory.upgrade_radius}m" },
          { name: "Max Objects", value: territory.upgrade_object_count },
          { name: "Price", value: territory.upgrade_price }
        )
      end

      field_info.push({ value: "__Territory Members__" }, { name: "Owner", value: territory.owner })

      # Now check the fields
      # Removing them from the embed so we can check moderators/builders easily
      field_info.each do |field|
        embed_field = embed.fields.shift
        expect(embed_field.name).to eql(field[:name].to_s) if field[:name].present?
        expect(embed_field.value).to eql(field[:value].to_s)
      end

      moderator_fields = build_fields(territory.moderators)
      moderator_fields.each do |moderator_field|
        field = embed.fields.shift
        expect(field.name).to match(/moderator/i)
        expect(field.value).to eql(moderator_field)
      end

      builder_fields = build_fields(territory.builders)
      builder_fields.each do |builder_field|
        field = embed.fields.shift
        expect(field.name).to match(/build rights/i)
        expect(field.value).to eql(builder_field)
      end
    end
  end
end
