# frozen_string_literal: true

describe ESM::Command::Server::Territories, category: "command" do
  let!(:command) { ESM::Command::Server::Territories.new }

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
      wait_for { wsc.connected? }.to be(true)

      # IMPORTANT!
      # If we don't reload the server model after WSC connection, the server settings will be wrong!
      server.reload
    end

    after :each do
      wsc.disconnect!
    end

    it "should return" do
      request = nil
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(response.size)

      ESM::Test.messages.map(&:second).each_with_index do |embed, index|
        territory = ESM::Arma::Territory.new(server: server, territory: response[index])

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

    it "should error (No territories)" do
      request = nil
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)
      wsc.flags.RETURN_NO_TERRITORIES = true

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/unable to find any territories/i)
      expect(embed.color).to eql(ESM::Color::Toast::RED)
    end
  end
end
