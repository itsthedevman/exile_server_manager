# frozen_string_literal: true

describe ESM::Command::ArgumentContainer do
  let!(:command) { ESM::Command::Test::Base.new }
  let!(:container) { command.arguments }
  let!(:user) { create(:user) }

  it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} arguments" do
    expect(container.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
  end

  describe "Valid Argument Container (Preserve)" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_FULL }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should have a valid event" do
      expect(event).not_to be_nil
      expect(event.message.content).to eql(content)
    end

    it "should parse" do
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} matches" do
      expect(container.matches.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
    end

    it "should preserve the case" do
      expect(container._preserve).to eql("PRESERVE")
    end
  end

  describe "Invalid Argument Container (Raises error/forgotten arguments)" do
    let!(:content) { "~base esm esm_malden 137709767954137088 1" }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should have a valid event" do
      expect(event).not_to be_nil
      expect(event.message.content).to eql(content)
    end

    it "should raise an error with a embed" do
      expect { container.parse!(event) }.to raise_error do |error|
        embed = error.data

        expect(embed.title).to eql("**Missing argument `<_preserve>` for `#{ESM.config.prefix}base`**")
        expect(embed.description).to eql("```#{ESM::Command::Test::Base::MISSING_ARGUMENT_USAGE} ```")
        expect(embed.fields.size).to eql(1)
        expect(embed.fields.first.name).to eql("Arguments:")
        expect(embed.fields.first.value).to eql(ESM::Command::Test::Base::COMMAND_AS_STRING)
        expect(embed.footer.text).to eql("For more information, send me `#{ESM.config.prefix}help base`")
      end
    end
  end

  describe "Valid Argument Container (Do not preserve)" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_FULL.dup.upcase }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should parse" do
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} matches" do
      expect(container.matches.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
    end

    it "should not preserve the case" do
      expect(container._display_as).to eql("display_as")
    end
  end

  describe "Valid Argument Container (Multiline/Preserve Case)" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_FULL.dup.upcase }
    let!(:event) { CommandEvent.create(content, user: user) }

    before :each do
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} matches" do
      expect(container.matches.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
    end

    it "should include the new lines and preserve case" do
      expect(container._multiline).to eql("MULTI\nLINE")
    end
  end

  describe "Valid Argument Container (Type)" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_FULL }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should parse" do
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} matches" do
      expect(container.matches.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
    end

    it "should be of type int" do
      expect(container._integer).to be_a(Integer)
    end

    it "should equal 1" do
      expect(container._integer).to eql(1)
    end
  end

  describe "Valid Argument Container (Default/provided)" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_FULL }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should parse" do
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} matches" do
      expect(container.matches.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
    end

    it "should not use the default value" do
      expect(container._default).to eql("default")
    end
  end

  describe "Valid Argument Container (Default/Empty)" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_MINIMAL }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should parse" do
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} matches" do
      expect(container.matches.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
    end

    it "should not use the default value" do
      expect(container._default).to eql("not_default")
    end
  end

  it "#to_s" do
    expect(container.to_s).to eql(ESM::Command::Test::Base::COMMAND_AS_STRING)
  end

  describe "#clear!" do
    it "should clear the values of all arguments" do
      expect(container.map(&:value).reject(&:nil?)).not_to be_empty
      container.clear!
      expect(container.map(&:value).reject(&:nil?)).to be_empty
    end
  end

  describe "#to_h" do
    it "should have all attributes and values" do
      hash = container.to_h
      expect(hash.keys).to match_array(container.map(&:name))
      expect(hash.values).to match_array(container.map(&:value))
    end
  end

  describe "Aliases" do
    let!(:content) { ESM::Command::Test::Base::COMMAND_MINIMAL_ALIAS }
    let!(:event) { CommandEvent.create(content, user: user) }

    it "should properly slice out alias correctly" do
      expect { container.parse!(event) }.not_to raise_error
    end
  end
end
