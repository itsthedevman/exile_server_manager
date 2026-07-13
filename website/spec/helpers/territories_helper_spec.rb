# frozen_string_literal: true

require "rails_helper"

RSpec.describe TerritoriesHelper, type: :helper do
  def member(role)
    ESM::Exile::Territory::Member.new(name: "Someone", steam_uid: "76561198000000000", role:)
  end

  describe "#pay_confirm_message" do
    it "names the price when the caller knows it" do
      expect(helper.pay_confirm_message("1,000 poptabs"))
        .to eq("Pay 1,000 poptabs from your locker now?")
    end

    it "falls back to a generic line when no price is given" do
      expect(helper.pay_confirm_message)
        .to eq("Pay this territory's protection from your locker now?")
    end
  end

  describe "#upgrade_confirm_message" do
    it "names the price when the caller knows it" do
      expect(helper.upgrade_confirm_message("500 poptabs"))
        .to eq("Upgrade this territory for 500 poptabs from your locker now?")
    end

    it "falls back to a generic line when no price is given" do
      expect(helper.upgrade_confirm_message)
        .to eq("Upgrade this territory from your locker now?")
    end
  end

  describe "#command_action_id" do
    it "keys the region on command, surface, and territory" do
      expect(helper.command_action_id("pay", "77", "modal")).to eq("pay_modal_77")
    end

    it "appends the target uid so a modal's many member rows stay distinct" do
      expect(helper.command_action_id("remove", "77", "modal", "76561198000000000"))
        .to eq("remove_modal_77_76561198000000000")
    end
  end

  describe "#territory_command_inline?" do
    it "is false for a full-width (block) command" do
      command = instance_double(ESM::ServerCommand, command_name: "pay")
      expect(helper.territory_command_inline?(command)).to be(false)
    end

    it "is true for an icon-sized (inline) command" do
      command = instance_double(ESM::ServerCommand, command_name: "remove")
      expect(helper.territory_command_inline?(command)).to be(true)
    end
  end

  describe "#territory_member_actions" do
    it "gives the owner no actions" do
      expect(helper.territory_member_actions(member(:owner))).to be_empty
    end

    it "lets a moderator be demoted or removed" do
      commands = helper.territory_member_actions(member(:moderator)).map { |action| action[:command_name] }
      expect(commands).to eq(%w[demote remove])
    end

    it "lets a builder be promoted or removed" do
      commands = helper.territory_member_actions(member(:builder)).map { |action| action[:command_name] }
      expect(commands).to eq(%w[promote remove])
    end
  end

  describe "#territory_flag_status_color" do
    it "is green while the territory is secure" do
      territory = instance_double(ESM::Exile::Territory, stolen?: false)
      expect(helper.territory_flag_status_color(territory)).to eq("text-success")
    end

    it "is red once the flag is stolen" do
      territory = instance_double(ESM::Exile::Territory, stolen?: true)
      expect(helper.territory_flag_status_color(territory)).to eq("text-danger")
    end
  end

  describe "#territory_level_display" do
    it "is just the level while the territory can still be upgraded" do
      territory = instance_double(ESM::Exile::Territory, level: 3, upgradeable?: true)
      expect(helper.territory_level_display(territory)).to eq("3")
    end

    it "tags the level with a muted (max) at the ceiling" do
      territory = instance_double(ESM::Exile::Territory, level: 7, upgradeable?: false)
      result = helper.territory_level_display(territory)

      expect(result).to include("7", "(max)", "text-secondary-emphasis")
    end
  end

  describe "#territory_command_failure_message" do
    it "hedges on a timeout, since the in-game side effect may still have landed" do
      command = instance_double(ESM::ServerCommand, command_name: "pay", timed_out?: true, error_message: nil)
      expect(helper.territory_command_failure_message(command)).to match(/didn't respond in time/)
    end

    it "shows the extension's own rejection verbatim" do
      command = instance_double(
        ESM::ServerCommand,
        command_name: "remove",
        timed_out?: false,
        error_message: "You are not a moderator."
      )

      expect(helper.territory_command_failure_message(command)).to eq("You are not a moderator.")
    end

    it "falls back to the command's generic line when nothing else fits" do
      command = instance_double(ESM::ServerCommand, command_name: "set_id", timed_out?: false, error_message: nil)
      expect(helper.territory_command_failure_message(command)).to match(/updating the territory ID/)
    end
  end
end
