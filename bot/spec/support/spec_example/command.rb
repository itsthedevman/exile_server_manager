RSpec.shared_examples("validate_command") do
  it "has a description" do
    expect(command.description).not_to be_blank
    expect(command.description).not_to match(/todo/i)
  end

  it "has examples" do
    expect(command.examples).not_to be_blank
  end

  it "has attributes" do
    defines = command.attributes.to_h
    expect(defines).to have_key(:enabled)
    expect(defines).to have_key(:allowlist_enabled)
    expect(defines).to have_key(:allowlisted_role_ids)
    expect(defines).to have_key(:allowed_in_text_channels)
    expect(defines).to have_key(:cooldown_time)
  end

  it "has a description for every argument" do
    command.arguments.each do |name, value|
      argument = command.arguments.templates[name]
      description = argument.description

      expect(description).not_to be_nil, "Argument \"#{name}\" has a nil description"
      expect(description.match?(/^translation missing/i)).to be(false), "Argument \"#{name}\" does not have a valid entry. Ensure `commands.#{command.name}.arguments.#{name}` exists in `config/locales/commands/#{name}/en.yml`"
      expect(description.match?(/todo/i)).to be(false), "Argument \"#{name}\" has a TODO description"
    end
  end
end

RSpec.shared_examples("arma_error_player_needs_to_join") do
  it "raises PlayerNeedsToJoin" do
    expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
      expect(error.data.description).to match("need to join")
    end
  end
end

RSpec.shared_examples("arma_error_target_needs_to_join") do
  it "raises TargetNeedsToJoin" do
    expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
      expect(error.data.description).to match("needs to join")
    end
  end
end

RSpec.shared_examples("arma_error_null_flag") do
  it "raises NullFlag and NullFlag_Admin" do
    expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
      expect(error.data.description).to match("I was unable to find a territory")
    end

    wait_for { ESM::Test.messages.size }.to eq(1)

    # Admin log
    expect(
      ESM::Test.messages.retrieve("territory flag was not found in game")
    ).not_to be_nil
  end
end

RSpec.shared_examples("arma_error_missing_territory_access") do
  it "raises MissingTerritoryAccess and MissingTerritoryAccess_Admin" do
    expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
      expect(error.data.description).to match("you do not have permission")
    end

    wait_for { ESM::Test.messages.size }.to eq(1)

    # Admin log
    expect(
      ESM::Test.messages.retrieve("Player attempted to perform an action on Territory")
    ).not_to be_nil
  end
end

RSpec.shared_examples("arma_error_flag_stolen") do
  it "raises StolenFlag" do
    expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
      expect(error.data.description).to match("has been stolen")
    end
  end
end

RSpec.shared_examples("arma_error_too_poor") do
  it "raises TooPoor" do
    expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
      expect(error.data.description).to match(/you do not have enough poptabs in your locker. It costs ..[\d,]+.. and you have ..[\d,]+../)
    end
  end
end
