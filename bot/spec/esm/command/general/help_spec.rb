# frozen_string_literal: true

describe ESM::Command::General::Help, category: "command" do
  include_context "command"
  include_examples "validate_command", requires_registration: false

  describe "#execute" do
    context "when there is no category provided" do
      it "sends the 'getting started' information" do
        execute!

        embed = ESM::Test.messages.first.content
        expect(embed.title).to match(/well, hello there .+/i)

        commands_by_type = ESM::Command.by_type
        expect(embed.description).to eq(
          I18n.t(
            "commands.help.getting_started.description",
            command_count_player: commands_by_type[:player].size,
            command_count_total: commands_by_type.values.flatten.size
          )
        )

        expect(embed.fields.size).to eq(3)

        %w[commands command privacy].each_with_index do |field_type, index|
          expect(embed.fields[index].name).to eq(I18n.t("commands.help.getting_started.fields.#{field_type}.name"))
          expect(embed.fields[index].value).to eq(I18n.t("commands.help.getting_started.fields.#{field_type}.value"))
        end
      end
    end

    context "when the category is 'commands'" do
      subject(:command_execution) { execute!(arguments: {category: "commands"}) }

      it "shows the commands" do
        command_execution

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil
      end

      it "does not show development commands" do
        command_execution

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil

        embed.fields.each do |field|
          expect(field.value).not_to match(/development/i)
        end
      end
    end

    context "when the category is 'admin commands'" do
      it "shows only admin commands" do
        execute!(arguments: {category: "admin commands"})

        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil
        expect(embed.title).to match(/admin commands/i)
        expect(embed.title).not_to match(/player commands/i)
      end
    end

    context "when the category is 'player commands'" do
      it "shows only player commands" do
        execute!(arguments: {category: "player commands"})

        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil
        expect(embed.title).to match(/player commands/i)
        expect(embed.title).not_to match(/admin commands/i)
      end
    end

    context "when the category is a command name" do
      it "returns the command's information" do
        execute!(arguments: {category: "help"})

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil
        expect(embed.title).to match(/help/i)
      end
    end

    context "when the category is a slash command" do
      it "returns the command's information" do
        execute!(arguments: {category: "/server my player"})

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil
        expect(embed.title).to match(/my player/i)
      end
    end

    context "when the current community is in player mode" do
      before do
        community.update!(player_mode_enabled: true)
      end

      it "does not show admin commands" do
        execute!(arguments: {category: "commands"})

        embed = ESM::Test.messages.first.content
        expect(embed).not_to be_nil

        embed.fields.each do |field|
          expect(field.value).not_to match(/admin|development/i)
        end
      end
    end
  end
end
