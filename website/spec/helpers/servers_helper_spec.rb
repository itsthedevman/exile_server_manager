# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServersHelper, type: :helper do
  let(:server) { create(:server, server_ip: "203.0.113.10", server_port: "2302") }

  describe "#server_address" do
    it "reads as the ip and port a player joins on" do
      expect(helper.server_address(server)).to eq("203.0.113.10:2302")
    end
  end

  describe "#server_restart_countdown" do
    it "counts down to the next restart while the server is up" do
      allow(server).to receive_messages(
        connected?: true, server_start_time?: true, time_left_before_restart: "2 hours"
      )

      expect(helper.server_restart_countdown(server)).to eq("2 hours")
    end

    # The sidebar's own status line already says the server is down, so there is nothing to add.
    it "gives nothing for a server that is down" do
      allow(server).to receive(:connected?).and_return(false)

      expect(helper.server_restart_countdown(server)).to be_nil
    end

    # connected? is cached separately from the start time, so the two can disagree for a moment after a restart.
    it "gives nothing when the start time hasn't landed yet, rather than counting from nil" do
      allow(server).to receive_messages(connected?: true, server_start_time?: false)

      expect(helper.server_restart_countdown(server)).to be_nil
    end
  end

  describe "#server_mod_groups" do
    it "leads with the mods a player must install, alphabetical within each group" do
      server.server_mods.create!(mod_name: "Zeus", mod_required: false)
      server.server_mods.create!(mod_name: "Exile", mod_version: "1.0.4", mod_required: true)
      server.server_mods.create!(mod_name: "CBA_A3", mod_version: "3.15", mod_required: true)

      groups = helper.server_mod_groups(server)

      expect(groups.map(&:label)).to eq(["Required mods", "Optional mods"])
      expect(groups.first.mods.map(&:mod_name)).to eq(%w[CBA_A3 Exile])
    end

    it "drops a group with nothing in it rather than showing an empty heading" do
      server.server_mods.create!(mod_name: "Exile", mod_required: true)

      expect(helper.server_mod_groups(server).map(&:label)).to eq(["Required mods"])
    end

    it "is empty for a server with no mods recorded" do
      expect(helper.server_mod_groups(server)).to be_empty
    end
  end

  describe "#server_mod_label" do
    it "names the mod and the version the owner recorded" do
      mod = server.server_mods.create!(mod_name: "Exile", mod_version: "1.0.4", mod_required: true)

      expect(helper.server_mod_label(mod)).to eq("Exile 1.0.4")
    end

    it "falls back to the name alone when no version was recorded" do
      mod = server.server_mods.create!(mod_name: "Exile", mod_required: true)

      expect(helper.server_mod_label(mod)).to eq("Exile")
    end
  end
end
