# frozen_string_literal: true

describe ESM::Command::Arguments do
  include_context "command"

  context "parses and stores the text with respect to its case" do
    let(:command_class) { ESM::Command::Test::ArgumentPreserveCase }

    specify do
      execute!(arguments: {input: "Hello!"})
      expect(previous_command.arguments.input).to eq("Hello!")
    end
  end

  context "parses and stores the text as lowercase" do
    let(:command_class) { ESM::Command::Test::ArgumentIgnoreCase }

    specify do
      execute!(arguments: {input: "World!"})
      expect(previous_command.arguments.input).to eq("world!")
    end
  end

  context "raises an error with an embed when an required argument is missing" do
    let(:command_class) { ESM::Command::Test::ArgumentRequired }

    specify do
      expect { execute! }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data

        expect(embed.title).to eq("**Invalid argument**")
        expect(embed.description).to eq("```/argument_required input:<input>```\n**Please read the following and correct any errors before trying again.**\n\n**Missing argument**\n**`input:`**\nDefaulted testing description\n\nFor more information, use the following command:\n```/help with:argument_required```\n")

        argument_field = embed.fields.first
        expect(argument_field.name).to eq("**__Examples__**")
      end
    end
  end

  context "parses and does not use the default because there was a value provided" do
    let(:command_class) { ESM::Command::Test::ArgumentDefault }

    specify do
      # input argument provided, no default
      execute!(arguments: {input: "success_from_input!"})
      expect(previous_command.arguments.input).to eq("success_from_input!")
    end
  end

  context "parses and uses the default because no value was provided" do
    let(:command_class) { ESM::Command::Test::ArgumentDefault }

    specify do
      execute! # input argument not provided, use default
      expect(previous_command.arguments.input).to eq("default success!")
    end
  end
end
