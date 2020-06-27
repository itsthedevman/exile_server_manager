# frozen_string_literal: true

describe ESM::Community do
  describe "#create_command_configurations" do
    it "should create configurations based off commands" do
      community = ESM::Test.community
      ESM::CommandConfiguration.where(community_id: community.id).in_batches(of: 10_000).destroy_all

      community.send(:create_command_configurations)
      community.reload

      expect(community.command_configurations.size).to eql(ESM::Command.all.size)

      ESM::Command.all.each do |command|
        expect(ESM::CommandConfiguration.where(community_id: community.id, command_name: command.name).any?).to be(true)
      end
    end
  end
end
