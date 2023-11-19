# frozen_string_literal: true

describe ESM::Command::Base::Checks do
  include_context "command" do
    let!(:command_class) { ESM::Command::Test::TargetCommand }
  end

  before do
    command.current_user = user
    command.current_channel = ESM::Test.channel
  end

  describe "#registered_target_user!" do
    it "does not raise (target_user is nil)" do
      command.instance_variable_set(:@target_user, nil)
      expect { command.check_for_registered_target_user! }.not_to raise_error
    end

    it "does not raise (target_user is registered)" do
      command.instance_variable_set(:@target_user, user)
      expect { command.check_for_registered_target_user! }.not_to raise_error
    end

    it "raises (target_user is of type User::Ephemeral)" do
      steam_uid = second_user.steam_uid
      second_user.destroy

      command.instance_variable_set(:@target_user, ESM::User::Ephemeral.new(steam_uid))
      expect { command.check_for_registered_target_user! }.to raise_error(ESM::Exception::CheckFailure, /has not registered with me yet/i)
    end

    it "raises (target_user is not registered)" do
      second_user.update!(steam_uid: "")

      command.instance_variable_set(:@target_user, second_user)
      expect { command.check_for_registered_target_user! }.to raise_error(ESM::Exception::CheckFailure, /has not registered with me yet/i)
    end
  end
end
