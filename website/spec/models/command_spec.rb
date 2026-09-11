# frozen_string_literal: true

RSpec.describe Command do
  describe ".all" do
    # Every request the process serves reads the same commands, so anything one request could write onto them would be
    # read back by the next, whichever community that one is for.
    it "is frozen, down to each command" do
      expect(described_class.all).to be_frozen
      expect(described_class.all.values).to all(be_frozen)
    end
  end

  describe "#with_configuration" do
    let(:command) { described_class.all.values.first }
    let(:configuration) { ESM::CommandConfiguration.new(command_name: command.name) }

    it "hands back a copy carrying the configuration and leaves the shared command without one" do
      configured = command.with_configuration(configuration)

      expect(configured.configuration).to eq(configuration)
      expect(configured.name).to eq(command.name)
      expect(command.configuration).to be_nil
    end
  end
end
