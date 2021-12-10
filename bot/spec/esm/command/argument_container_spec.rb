# frozen_string_literal: true

describe ESM::Command::ArgumentContainer do
  # Note: This requires ESM everything
  let!(:command) { ESM::Command::Test::Base.new }
  let!(:community) { create(:esm_community) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }
  let!(:container) { command.arguments }
  let(:event) { CommandEvent.create(command_statement, user: user) }

  let!(:command_statement) do
    command.statement(
      community_id: community.community_id,
      server_id: server.server_id,
      target: user.discord_id,
      _integer: "1",
      _preserve: "PRESERVE",
      _display_as: "display_as",
      _default: "default",
      _multiline: "multi\nline"
    )
  end

  it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} arguments" do
    expect(container.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
  end

  describe "Valid Argument Container (Preserve)" do
    before :each do
      expect(event).not_to be_nil
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
    let!(:command_statement) do
      command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1"
      )
    end

    it "should have a valid event" do
      expect(event).not_to be_nil
    end

    it "should raise an error with a embed" do
      expect { container.parse!(event) }.not_to raise_error
      expect { container.validate! }.to raise_error do |error|
        embed = error.data

        expect(embed.title).to eql("**Missing argument `<_preserve>` for `#{ESM.config.prefix}base`**")
        expect(embed.description).to match(/```.+base #{community.community_id} #{server.server_id} #{user.discord_id} 1 <_preserve> <sa_yalpsid> not_default <\?_multiline> ```/)
        expect(embed.fields.size).to eql(1)
        expect(embed.fields.first.name).to eql("Arguments:")
        expect(embed.fields.first.value).to eql(ESM::Command::Test::Base::COMMAND_AS_STRING)
        expect(embed.footer.text).to match(/for more information, send me `.+help base`/i)
      end
    end
  end

  describe "Valid Argument Container (Do not preserve)" do
    let!(:command_statement) do
      command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "DISPLAY_AS"
      )
    end

    before :each do
      expect(event).not_to be_nil
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
    let!(:command_statement) do
      command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "DISPLAY_AS",
        _default: "DEFAULT",
        _multiline: "MULTI\nLINE"
      )
    end

    before :each do
      expect(event).not_to be_nil
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
    let!(:command_statement) do
      command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as",
        _default: "default",
        _multiline: "multi\nline"
      )
    end

    before :each do
      expect(event).not_to be_nil
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
    let!(:command_statement) do
      command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as",
        _default: "default",
        _multiline: "multi\nline"
      )
    end

    before :each do
      expect(event).not_to be_nil
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
    let!(:command_statement) do
      command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
    end

    before :each do
      expect(event).not_to be_nil
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
    before :each do
      expect(event).not_to be_nil
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should clear the values of all arguments" do
      expect(container.map(&:value).reject(&:nil?)).not_to be_empty
      container.clear!
      expect(container.map(&:value).reject(&:nil?)).to be_empty
    end
  end

  describe "#to_h" do
    before :each do
      expect(event).not_to be_nil
      expect { container.parse!(event) }.not_to raise_error
    end

    it "should have all attributes and values" do
      hash = container.to_h
      expect(hash.keys).to match_array(container.map(&:name))
      expect(hash.values).to match_array(container.map(&:value))
    end
  end

  describe "Aliases" do
    let!(:command_statement) do
      command.statement(
        _use_alias: "base1",
        community_id: "esm",
        server_id: "esm_malden",
        target: "137709767954137088",
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
    end

    it "should properly slice out alias correctly" do
      expect { container.parse!(event) }.not_to raise_error
    end
  end
end
