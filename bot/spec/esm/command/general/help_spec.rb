# frozen_string_literal: true

describe ESM::Command::General::Help, category: "command" do
  let!(:command) { ESM::Command::General::Help.new }

  it "be valid" do
    expect(command).not_to be_nil
  end

  it "has 1 argument" do
    expect(command.arguments.size).to eql(1)
  end

  it "has a description" do
    expect(command.description).not_to be_blank
  end

  it "has examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }

    it "executes with default getting started" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed.title).to match(/well, hello there .+/i)

      commands_by_type = ESM::Command.by_type
      expect(embed.description).to eq(
        I18n.t(
          "commands.help.getting_started.description",
          command_count_player: commands_by_type[:player].size,
          command_count_total: commands_by_type.values.flatten.size,
          prefix: command.prefix
        )
      )

      expect(embed.fields.size).to eq(3)

      %w[commands command privacy].each_with_index do |field_type, index|
        expect(embed.fields[index].name).to eq(I18n.t("commands.help.getting_started.fields.#{field_type}.name"))
        expect(embed.fields[index].value).to eq(I18n.t("commands.help.getting_started.fields.#{field_type}.value", prefix: command.prefix))
      end
    end

    it "returns a valid embed (commands)" do
      command_statement = command.statement(category: "commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil
    end

    it "returns a valid embed (command)" do
      command_statement = command.statement(category: "help")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil
    end

    it "does not show admin commands if in player mode (commands)" do
      community.update(player_mode_enabled: true)

      command_statement = command.statement(category: "commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil

      embed.fields.each do |field|
        expect(field.value).not_to match(/admin|development/i)
      end
    end

    it "does not show development commands" do
      command_statement = command.statement(category: "commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil

      embed.fields.each do |field|
        expect(field.value).not_to match(/development/i)
      end
    end

    it "shows only player commands" do
      command_statement = command.statement(category: "player commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil
      expect(embed.title).to match(/player commands/i)
      expect(embed.title).not_to match(/admin commands/i)
    end

    it "shows only admin commands" do
      command_statement = command.statement(category: "admin commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(ESM::Test.messages.size).to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil
      expect(embed.title).to match(/admin commands/i)
      expect(embed.title).not_to match(/player commands/i)
    end
  end
end
