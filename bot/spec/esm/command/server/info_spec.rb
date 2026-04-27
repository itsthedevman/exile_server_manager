# frozen_string_literal: true

describe ESM::Command::Server::Info, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is an admin command" do
    expect(command.type).to eq(:admin)
  end

  before do
    grant_command_access!(community, "info")
  end

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      before do
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

  describe "V2", v2: true do
    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let(:territory_id) { nil }
      let(:target) { user.mention }

      subject(:execute_command) do
        execute!(arguments: {server_id: server.server_id, target:, territory_id:})
      end

      context "when the target is a player" do
        context "and the player is alive" do
          before do
            spawn_player_for(user)
          end

          it "is expected to return information on the player" do
            execute_command

            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = latest_message
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

        context "and the player is dead" do
          before do
            user.exile_player.destroy!
          end

          it "is expected to return information about the player" do
            execute_command

            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = latest_message
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
      end

      context "when the target is a steam uid" do
        let!(:target) { user.steam_uid }

        before do
          user.exile_player
        end

        it "is expected to return information about the player" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = latest_message
          expect(embed.title).to match(/stats on `#{server.server_id}`/i)
        end
      end

      context "when the target has not joined the server" do
        let!(:target) { user.steam_uid }

        include_examples "raises_check_failure" do
          let!(:matcher) { "I didn't find any player information related" }
        end
      end

      context "when the target is a territory" do
        let!(:target) { nil }
        let!(:territory_id) { territory.encoded_id }

        it "is expected to return information about the territory" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = latest_message
          exile_territory = ESM::Exile::Territory.new(server: server, territory: territory.to_h)

          expect(embed.title).to eq("Territory \"#{exile_territory.name}\"")
          expect(embed.thumbnail.url).to eq(exile_territory.flag_path)
          expect(embed.color).to eq(exile_territory.status_color)
          expect(embed.description).to eq(exile_territory.payment_reminder_message)

          field_info = [
            {name: "Territory ID", value: "```#{exile_territory.id}```"},
            {name: "Flag Status", value: "```#{exile_territory.flag_status}```"},
            {
              name: "Next Due Date",
              value: "```#{exile_territory.next_due_date.strftime(ESM::Time::Format::TIME)}```"
            },
            {
              name: "Last Paid",
              value: "```#{exile_territory.last_paid_at.strftime(ESM::Time::Format::TIME)}```"
            },
            {name: "Price to renew protection", value: exile_territory.renew_price},
            {value: "__Current Territory Stats__"},
            {name: "Level", value: exile_territory.level},
            {name: "Radius", value: "#{exile_territory.radius}m"},
            {
              name: "Current / Max Objects",
              value: "#{exile_territory.object_count}/#{exile_territory.max_object_count}"
            }
          ]

          if exile_territory.upgradeable?
            field_info.push(
              {value: "__Next Territory Stats__"},
              {name: "Level", value: exile_territory.upgrade_level},
              {name: "Radius", value: "#{exile_territory.upgrade_radius}m"},
              {name: "Max Objects", value: exile_territory.upgrade_object_count},
              {name: "Price", value: exile_territory.upgrade_price}
            )
          end

          field_info.push(
            {value: "__Territory Members__"},
            {name: ":crown: Owner", value: exile_territory.owner}
          )

          # Now check the fields
          # Removing them from the embed so we can check moderators/builders easily
          field_info.each do |field|
            embed_field = embed.fields.shift
            expect(embed_field.name).to eq(field[:name].to_s) if field[:name].present?
            expect(embed_field.value).to eq(field[:value].to_s)
          end

          if exile_territory.moderators.present?
            moderator_fields = ESM::Embed.new
              .add_field(value: exile_territory.moderators)
              .fields
              .map(&:value)

            moderator_fields.each do |moderator_field|
              field = embed.fields.shift
              expect(field.name).to match(/moderator/i)
              expect(field.value).to eq(moderator_field)
            end
          end

          if exile_territory.builders.present?
            builder_fields = ESM::Embed.new
              .add_field(value: exile_territory.builders)
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

      context "when the target is not a valid territory" do
        let!(:territory_id) { "12345" }

        include_examples "error_territory_id_does_not_exist"
      end

      context "when the target is not provided" do
        let!(:target) { nil }

        include_examples "raises_check_failure" do
          let!(:matcher) { "you must provide" }
        end
      end
    end
  end
end
