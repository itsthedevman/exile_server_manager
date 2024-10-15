# frozen_string_literal: true

describe ESM::Command::Server::Info, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    before do
      grant_command_access!(community, "info")

      # IMPORTANT!
      # If we don't reload the server model after WSC connection, the server settings will be wrong!
      server.reload
    end

    context "when the mentioned target is alive" do
      it "returns information on the player" do
        wsc.flags.PLAYER_ALIVE = true

        request = execute!(arguments: {server_id: server.server_id, target: user.mention})
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
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
    end

    context "when the steam uid target is a dead player" do
      it "returns information on the player" do
        request = execute!(arguments: {server_id: server.server_id, target: user.steam_uid})
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.title).to match(/stats on `#{server.server_id}`/i)

        field = embed.fields.first
        expect(field.name).to match(/general/i)
        expect(field.value).to match("**You are dead**")

        field = embed.fields.second
        expect(field.name).to match(/currency/i)
        expect(field.value).to match(/money.+you are dead.+locker.+poptabs.+respect.+/im)

        field = embed.fields.third
        expect(field.name).to match(/scoreboard/i)
        expect(field.value).to match(/kills.+deaths.+kd ratio.+/im)
      end
    end

    context "when the target is a territory ID" do
      it "returns information on the territory" do
        request = execute!(arguments: {server_id: server.server_id, territory_id: "12345"})
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        territory = ESM::Exile::Territory.new(server: server, territory: response)

        expect(embed.title).to eq("Territory \"#{territory.name}\"")
        expect(embed.thumbnail.url).to eq(territory.flag_path)
        expect(embed.color).to eq(territory.status_color)
        expect(embed.description).to eq(territory.payment_reminder_message)

        field_info = [
          {name: "Territory ID", value: "```#{territory.id}```"},
          {name: "Flag Status", value: "```#{territory.flag_status}```"},
          {name: "Next Due Date", value: "```#{territory.next_due_date.strftime(ESM::Time::Format::TIME)}```"},
          {name: "Last Paid", value: "```#{territory.last_paid_at.strftime(ESM::Time::Format::TIME)}```"},
          {name: "Price to renew protection", value: territory.renew_price},
          {value: "__Current Territory Stats__"},
          {name: "Level", value: territory.level},
          {name: "Radius", value: "#{territory.radius}m"},
          {name: "Current / Max Objects", value: "#{territory.object_count}/#{territory.max_object_count}"}
        ]

        if territory.upgradeable?
          field_info.push(
            {value: "__Next Territory Stats__"},
            {name: "Level", value: territory.upgrade_level},
            {name: "Radius", value: "#{territory.upgrade_radius}m"},
            {name: "Max Objects", value: territory.upgrade_object_count},
            {name: "Price", value: territory.upgrade_price}
          )
        end

        field_info.push({value: "__Territory Members__"}, {name: ":crown: Owner", value: territory.owner})

        # Now check the fields
        # Removing them from the embed so we can check moderators/builders easily
        field_info.each do |field|
          embed_field = embed.fields.shift
          expect(embed_field.name).to eq(field[:name].to_s) if field[:name].present?
          expect(embed_field.value).to eq(field[:value].to_s)
        end

        moderator_fields = ESM::Embed.new
          .add_field(value: territory.moderators)
          .fields
          .map(&:value)

        moderator_fields.each do |moderator_field|
          field = embed.fields.shift
          expect(field.name).to match(/moderator/i)
          expect(field.value).to eq(moderator_field)
        end

        builder_fields = ESM::Embed.new
          .add_field(value: territory.builders)
          .fields
          .map(&:value)

        builder_fields.each do |builder_field|
          field = embed.fields.shift
          expect(field.name).to match(/builder/i)
          expect(field.value).to eq(builder_field)
        end
      end
    end
  end
end
