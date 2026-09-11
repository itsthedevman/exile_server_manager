# frozen_string_literal: true

RSpec.describe TerritoriesHelper, type: :helper do
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
      command = instance_double(ESM::ServiceCommand, command_name: "pay")
      expect(helper.territory_command_inline?(command)).to be(false)
    end

    it "is true for an icon-sized (inline) command" do
      command = instance_double(ESM::ServiceCommand, command_name: "remove")
      expect(helper.territory_command_inline?(command)).to be(true)
    end
  end

  describe "#territory_member_actions" do
    # Which actions a member row offers depends on who is asking: the command has to be open to the viewer, and the
    # viewer has to hold the role arma checks for it or territory-admin rights. Those answers come from the request, so
    # a helper spec supplies them the way a controller would. They reach a view as controller helper_methods rather than
    # as methods on the view itself, so verification has to stand down to stub them.
    let(:owner) { ESM::Exile::Territory::Member.new(name: "Owner", steam_uid: "76561198000000001", role: :owner) }
    let(:moderator) { ESM::Exile::Territory::Member.new(name: "Mod", steam_uid: "76561198000000002", role: :moderator) }
    let(:builder) { ESM::Exile::Territory::Member.new(name: "Builder", steam_uid: "76561198000000003", role: :builder) }
    let(:territory) { instance_double(ESM::Exile::Territory, id: "77", owner:, moderators: [moderator], builders: [builder]) }
    let(:viewer_uid) { moderator.steam_uid }
    let(:territory_admin) { false }

    before do
      without_partial_double_verification do
        allow(helper).to receive_messages(
          command_accessible?: true,
          territory_admin?: territory_admin,
          current_user: build(:user, steam_uid: viewer_uid)
        )
      end
    end

    def commands_for(member)
      helper.territory_member_actions(member, territory:).map { |action| action[:command_name] }
    end

    it "gives the owner no actions" do
      expect(commands_for(owner)).to be_empty
    end

    it "lets a moderator be demoted or removed" do
      expect(commands_for(moderator)).to eq(%w[demote remove])
    end

    it "lets a builder be promoted or removed" do
      expect(commands_for(builder)).to eq(%w[promote remove])
    end

    context "when the viewer only has build rights" do
      let(:viewer_uid) { builder.steam_uid }

      it "offers nothing, since arma wants a moderator for every member action" do
        expect(commands_for(moderator)).to be_empty
        expect(commands_for(builder)).to be_empty
      end
    end

    context "when the viewer holds no stake in the territory" do
      let(:viewer_uid) { "76561198000000009" }

      it "offers nothing" do
        expect(commands_for(moderator)).to be_empty
        expect(commands_for(builder)).to be_empty
      end

      context "and is a territory admin" do
        let(:territory_admin) { true }

        it "offers what a moderator would get" do
          expect(commands_for(builder)).to eq(%w[promote remove])
        end
      end
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
      command = instance_double(ESM::ServiceCommand, command_name: "pay", timed_out?: true, error_message: nil)
      expect(helper.territory_command_failure_message(command)).to match(/didn't respond in time/)
    end

    it "shows the extension's own rejection verbatim" do
      command = instance_double(
        ESM::ServiceCommand,
        command_name: "remove",
        timed_out?: false,
        error_message: "You are not a moderator."
      )

      expect(helper.territory_command_failure_message(command)).to eq("You are not a moderator.")
    end

    it "falls back to the command's generic line when nothing else fits" do
      command = instance_double(ESM::ServiceCommand, command_name: "set_id", timed_out?: false, error_message: nil)
      expect(helper.territory_command_failure_message(command)).to match(/updating the territory ID/)
    end
  end

  describe "#territory_role_at_least?" do
    let(:owner) { ESM::Exile::Territory::Member.new(name: "Owner", steam_uid: "76561198000000001", role: :owner) }
    let(:moderator) { ESM::Exile::Territory::Member.new(name: "Mod", steam_uid: "76561198000000002", role: :moderator) }
    let(:builder) { ESM::Exile::Territory::Member.new(name: "Builder", steam_uid: "76561198000000003", role: :builder) }
    let(:territory) { instance_double(ESM::Exile::Territory, owner:, moderators: [moderator], builders: [builder]) }

    it "ranks the owner above a moderator, and a moderator above build rights" do
      expect(helper.territory_role_at_least?(territory, owner.steam_uid, :owner)).to be(true)
      expect(helper.territory_role_at_least?(territory, moderator.steam_uid, :owner)).to be(false)
      expect(helper.territory_role_at_least?(territory, moderator.steam_uid, :moderator)).to be(true)
      expect(helper.territory_role_at_least?(territory, builder.steam_uid, :moderator)).to be(false)
      expect(helper.territory_role_at_least?(territory, builder.steam_uid, :builder)).to be(true)
    end

    it "gives a non-member nothing" do
      expect(helper.territory_role_at_least?(territory, "76561198000000009", :builder)).to be(false)
    end

    it "lets a territory admin through without being a member" do
      expect(helper.territory_role_at_least?(territory, "76561198000000009", :owner, admin: true)).to be(true)
    end

    it "is false when the viewer has no steam uid, even for a territory admin" do
      expect(helper.territory_role_at_least?(territory, nil, :builder, admin: true)).to be(false)
    end
  end

  describe "#territory_command_copy for add's two outcomes" do
    it "reads as a sent request by default" do
      command = instance_double(ESM::ServiceCommand, command_name: "add", result: {outcome: "requested"})
      expect(helper.territory_command_copy(command)[:past_tense]).to eq("Request sent")
    end

    it "reads as an immediate add when the row recorded the added outcome" do
      command = instance_double(ESM::ServiceCommand, command_name: "add", result: {outcome: "added"})
      expect(helper.territory_command_copy(command)[:past_tense]).to eq("Added")
    end

    it "leaves another command's copy untouched even if the row carries an outcome" do
      command = instance_double(ESM::ServiceCommand, command_name: "pay", result: {outcome: "added"})
      expect(helper.territory_command_copy(command)[:past_tense]).to eq("Paid")
    end
  end
end
