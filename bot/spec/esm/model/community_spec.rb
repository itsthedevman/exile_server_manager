# frozen_string_literal: true

describe ESM::Community do
  describe "#create_command_configurations" do
    it "should create configurations based off commands" do
      community = ESM::Test.community
      ESM::CommandConfiguration.where(community_id: community.id).in_batches(of: 10_000).destroy_all

      community.send(:create_command_configurations)
      community.reload

      expect(community.command_configurations.size).to eq(ESM::Command.all.size)

      ESM::Command.all.each do |command|
        expect(ESM::CommandConfiguration.where(community_id: community.id, command_name: command.command_name).any?).to be(true)
      end
    end
  end

  # rubocop:disable Rails/DynamicFindBy
  describe "#find_by_server_id" do
    let(:community) { ESM::Test.community }
    let(:server) { ESM::Test.server }

    it "should find the community by a server id" do
      result = ESM::Community.find_by_server_id(server.server_id)
      expect(result).not_to be(nil)
      expect(result).to eq(community)
    end

    it "should return nil (no id)" do
      result = ESM::Community.find_by_server_id(nil)
      expect(result).to be(nil)

      result = ESM::Community.find_by_server_id("")
      expect(result).to be(nil)
    end

    it "should return nil (bad input)" do
      result = ESM::Community.find_by_server_id("FooBarBaz")
      expect(result).to be(nil)

      result = ESM::Community.find_by_server_id("billy_everyteen")
      expect(result).to be(nil)
    end
  end
  # rubocop:enable Rails/DynamicFindBy
end
