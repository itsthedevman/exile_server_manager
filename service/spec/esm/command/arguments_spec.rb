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
      expect { execute! }.to raise_error(ESM::Exception::InvalidArguments) do |error|
        embed = error.to_embed

        expect(embed.title).to eq("**Invalid argument**")
        expect(embed.description).to eq("```/argument_required input:<input>```\n**Please read the following and correct any errors before trying again.**\n\n**Invalid argument**\n**`input:`**\nDefaulted testing description\n\nFor more information, use the following command:\n```/help with:argument_required```\n")

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

  describe "origin filtering" do
    let(:command_class) { ESM::Command::Test::ArgumentOrigins }
    let(:values) { {shared: "yes", website_only: "yes"} }

    let(:discord_origin) { ESM::Discord::Command::Origin.new(user:, community:) }
    let(:website_origin) { ESM::Website::Command::SyncOrigin.new(Datum.new(user:, community:, arguments: {})) }

    # Filtering happens on the way in rather than at validation, so an argument the origin may not supply never
    # exists on the instance. A caller that sends one anyway has it dropped instead of smuggled through.
    context "when the command came from Discord" do
      subject(:command) { command_class.new(origin: discord_origin, arguments: values) }

      it "drops the arguments Discord may not supply" do
        expect(command.arguments.keys).to contain_exactly(:shared)
        expect(command.arguments.shared).to eq("yes")
        expect(command.arguments.website_only).to be_nil
      end
    end

    context "when the command came from the website" do
      subject(:command) { command_class.new(origin: website_origin, arguments: values) }

      it "keeps every argument" do
        expect(command.arguments.keys).to contain_exactly(:shared, :website_only)
        expect(command.arguments.website_only).to eq("yes")
      end
    end

    # Help documentation and the command registry build commands without one, and they need to see the full set.
    context "when the command has no origin" do
      subject(:command) { command_class.new(arguments: values) }

      it "keeps every argument" do
        expect(command.arguments.keys).to contain_exactly(:shared, :website_only)
      end
    end
  end
end
