# frozen_string_literal: true

describe ESM::Command::Base::Definition do
  describe ".to_details" do
    subject(:details) { command_class.to_details }

    let(:command_class) { ESM::Command::Test::ArgumentDescriptions }

    it "describes the command" do
      expect(details).to include(
        name: command_class.command_name,
        type: command_class.type,
        category: command_class.category,
        usage: command_class.usage(with_args: false)
      )
    end

    # The website renders its documentation off the display name, which is what a player types on Discord, rather
    # than the internal name the command reads.
    it "keys the arguments by their display name" do
      expect(details[:arguments]).to include(:display_name)
      expect(details[:arguments][:display_name]).to include(name: :display_name)
    end

    # Documentation describes what someone can type. An argument the website supplies for itself is not part of
    # that, so it never reaches the page.
    context "when an argument is not available to Discord" do
      let(:command_class) { ESM::Command::Test::ArgumentOrigins }

      it "leaves it out" do
        expect(details[:arguments].keys).to contain_exactly(:shared)
      end
    end
  end

  describe ".unreleased" do
    subject(:command_class) { ESM::Command::Test::UnreleasedCommand }

    it "is expected to be marked as unreleased" do
      expect(command_class.released).to be(false)
      expect(command_class.released?).to be(false)
    end
  end
end
