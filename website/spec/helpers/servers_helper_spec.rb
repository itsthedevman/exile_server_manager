# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServersHelper, type: :helper do
  let(:server) { create(:server, server_ip: "203.0.113.10", server_port: "2302") }

  describe "#server_address" do
    it "reads as the ip and port a player joins on" do
      expect(helper.server_address(server)).to eq("203.0.113.10:2302")
    end
  end

  describe "#server_restart_at" do
    it "is one restart interval on from when the server last started" do
      started_at = 1.hour.ago
      allow(server).to receive_messages(
        connected?: true, server_start_time?: true, server_start_time: started_at, restart_interval: 3.hours
      )

      expect(helper.server_restart_at(server)).to be_within(1.second).of(started_at + 3.hours)
    end

    # The sidebar's own status line already says the server is down, so there is nothing to add.
    it "gives nothing for a server that is down" do
      allow(server).to receive(:connected?).and_return(false)

      expect(helper.server_restart_at(server)).to be_nil
    end

    # connected? is cached separately from the start time, so the two can disagree for a moment after a restart.
    it "gives nothing when the start time hasn't landed yet, rather than counting from nil" do
      allow(server).to receive_messages(connected?: true, server_start_time?: false)

      expect(helper.server_restart_at(server)).to be_nil
    end
  end

  describe "#server_mod_groups" do
    it "leads with the mods a player must install, alphabetical within each group" do
      server.server_mods.create!(mod_name: "Zeus", mod_required: false)
      server.server_mods.create!(mod_name: "Exile", mod_version: "1.0.4", mod_required: true)
      server.server_mods.create!(mod_name: "CBA_A3", mod_version: "3.15", mod_required: true)

      groups = helper.server_mod_groups(server)

      expect(groups.map(&:label)).to eq(["Required mods (2)", "Optional mods (1)"])
      expect(groups.first.mods.map(&:mod_name)).to eq(%w[CBA_A3 Exile])
    end

    # The list collapses, so the count is the only part a player sees without asking for it.
    it "counts the group in its label" do
      3.times { |i| server.server_mods.create!(mod_name: "Mod#{i}", mod_required: true) }

      expect(helper.server_mod_groups(server).first.label).to eq("Required mods (3)")
    end

    it "gives each group a dom id for its collapse to hang off" do
      server.server_mods.create!(mod_name: "Zeus", mod_required: false)
      server.server_mods.create!(mod_name: "Exile", mod_required: true)

      expect(helper.server_mod_groups(server).map(&:dom_id))
        .to eq(["server-mods-required", "server-mods-optional"])
    end

    it "drops a group with nothing in it rather than showing an empty heading" do
      server.server_mods.create!(mod_name: "Exile", mod_required: true)

      expect(helper.server_mod_groups(server).map(&:label)).to eq(["Required mods (1)"])
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

  describe "#render_setting" do
    # A setting the owner never touched, or set back to the default, is written as a comment so the generated
    # config.yml documents what the value would be without pinning it.
    it "comments out a setting left at its default" do
      settings = {updater_enabled: true}.with_indifferent_access

      expect(helper.render_setting(:updater_enabled, settings)).to eq("# updater_enabled: true")
    end

    it "comments out a setting that was never set" do
      expect(helper.render_setting(:updater_enabled, {}.with_indifferent_access)).to eq("# updater_enabled: true")
    end

    # The one that matters for a toggle: `false` is a choice, not an absent value. Rendering it as a comment would
    # ship a config.yml that leaves the feature on while the website shows it switched off.
    it "writes a real key for a boolean turned off" do
      settings = {updater_enabled: false}.with_indifferent_access

      expect(helper.render_setting(:updater_enabled, settings)).to eq("updater_enabled: false")
    end

    it "writes a real key for a value that differs from the default" do
      settings = {number_locale: "de"}.with_indifferent_access

      expect(helper.render_setting(:number_locale, settings)).to eq('number_locale: "de"')
    end
  end
end
