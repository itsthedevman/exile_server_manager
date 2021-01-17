# frozen_string_literal: true

describe ESM::Command::Base::Checks do
  let!(:command) { ESM::Command::Test::TargetCommand.new }
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let!(:second_user) { ESM::Test.second_user }

  before :each do
    command.instance_variable_set("@current_user", user.discord_user)
  end

  describe "#nil_targets!"
  describe "#text_only!"
  describe "#dm_only!"
  describe "#permissions!"
  describe "#registered!"
  describe "#cooldown!"
  describe "#dev_only!"
  describe "#connected_server!"
  describe "#nil_target_server!"
  describe "#nil_target_community!"
  describe "#nil_target_user!"
  describe "#player_mode!"
  describe "#different_community!"
  describe "#pending_request!"
  describe "#owned_server!"

  describe "#registered_target_user!" do
    it "should not raise (target_user is nil)" do
      command.instance_variable_set("@target_user", nil)
      expect { command.checks.registered_target_user! }.not_to raise_error
    end

    it "should not raise (target_user is registered)" do
      command.instance_variable_set("@target_user", user.discord_user)
      expect { command.checks.registered_target_user! }.not_to raise_error
    end

    it "should raise (target_user is of type TargetUser)" do
      steam_uid = second_user.steam_uid
      second_user.destroy

      command.instance_variable_set("@target_user", ESM::TargetUser.new(steam_uid))
      expect { command.checks.registered_target_user! }.to raise_error(ESM::Exception::CheckFailure, /has not registered with me yet/i)
    end

    it "should raise (target_user is not registered)" do
      second_user.update!(steam_uid: "")

      command.instance_variable_set("@target_user", second_user)
      expect { command.checks.registered_target_user! }.to raise_error(ESM::Exception::CheckFailure, /has not registered with me yet/i)
    end
  end
end
