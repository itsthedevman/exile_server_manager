# frozen_string_literal: true

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
