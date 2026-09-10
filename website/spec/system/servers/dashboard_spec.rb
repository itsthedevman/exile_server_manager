# frozen_string_literal: true

require "system_helper"

# The permission matrix, and the reason this page earns a browser rather than a request spec. What a person sees here
# is decided by four gates that answer independently - Steam registration, the server's own version, Discord's
# administrator flag or a command allowlist, and community management rights - and the page is a different page under
# each combination. Checking them by hand means logging in as four people.
#
# Every gate resolves through the bot, so `service_api` is where each example says who the viewer is. It starts fully
# denied, which means an example asserting something is visible has to have granted it, and an example asserting
# something is gone cannot pass by accident because the harness never granted it in the first place.
RSpec.describe "The server dashboard", type: :system do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  let(:trusted_role_id) { "540276267061215253" }

  before do
    login_as(user, scope: :user)

    # Every command this page gates on targets the server, and a command targeting an offline server is refused
    # before its allowlist is ever read. Leaving this false would deny the whole page for a reason that has nothing
    # to do with the permission under test, so an online server is the baseline and offline gets its own example.
    service_api.server_connected = true
  end

  def visit_dashboard
    visit server_path(server.public_id)
  end

  def sidebar
    find("#server-sidebar")
  end

  context "when the viewer has no Steam account linked" do
    let(:user) { create(:user, steam_uid: nil) }

    it "asks them to link one and offers nothing else" do
      visit_dashboard

      expect(page).to have_content("Link your Steam account to get started")

      # Registration gates the player surfaces and the admin ones alike, so nothing past the prompt should have
      # rendered - including in the rail, which asks the question separately from the body.
      expect(page).to have_no_content("My Player")
      expect(page).to have_no_content("Gamble")
      expect(page).to have_no_css("h2", text: /admin tools/i)
      expect(sidebar).to have_no_link("My Player")
    end
  end

  context "when the viewer is a registered player holding no roles" do
    it "gets the player cards and no sign that the admin surfaces exist" do
      visit_dashboard

      expect(page).to have_content("My Player")
      expect(page).to have_content("Gamble")
      expect(page).to have_content("Rewards")
      expect(sidebar).to have_link("My Player")

      # The three admin commands default to an allowlist with nothing on it, so a player clears none of them. The
      # heading is the tell: it renders only when at least one admin surface is reachable, so its absence says the
      # section was never built rather than built and left empty.
      expect(page).to have_no_css("h2", text: /admin tools/i)
      expect(page).to have_no_content("SQF Console")
      expect(page).to have_no_field("q")
      expect(sidebar).to have_no_link("Players")
      expect(sidebar).to have_no_link("Territories")

      # Managing the community is its own grant, and this viewer was given nothing.
      expect(sidebar).to have_no_link("Manage Server")
    end
  end

  context "when the viewer holds Discord's administrator permission" do
    before { service_api.administrator = true }

    it "clears every command allowlist without any of them being configured" do
      visit_dashboard

      expect(page).to have_css("h2", text: /admin tools/i)
      expect(page).to have_content("SQF Console")
      expect(page).to have_field("q")
      expect(sidebar).to have_link("Players")
      expect(sidebar).to have_link("Territories")

      # The player cards are not an admin grant and should be unaffected.
      expect(page).to have_content("My Player")

      # Administrator is Discord's permission inside the guild; managing the community here is a separate answer
      # from the bot, and this example never gave it. The two gates being independent is the whole point of asking.
      expect(sidebar).to have_no_link("Manage Server")
    end
  end

  context "when the viewer holds a role the community allowlisted for one command" do
    before do
      create(
        :command_configuration,
        community:,
        command_name: "sqf",
        allowlist_enabled: true,
        allowlisted_role_ids: [trusted_role_id]
      )

      service_api.role_ids = [trusted_role_id]
    end

    it "opens that command and leaves the rest of the admin surfaces shut" do
      visit_dashboard

      expect(page).to have_content("SQF Console")

      # Same viewer, same page, same admin section: these three are gone because their allowlists are still empty,
      # not because the section failed to render. A grant leaking across commands would show up right here.
      expect(page).to have_no_field("q")
      expect(sidebar).to have_no_link("Players")
      expect(sidebar).to have_no_link("Territories")
    end
  end

  context "when the viewer can manage the community" do
    before { service_api.modifiable_by = true }

    it "gets the door into the management side without any command access coming with it" do
      visit_dashboard

      expect(sidebar).to have_link("Manage Server")

      # Managing a community is not permission to run its commands. An admin surface appearing here would mean the
      # page is reading one answer where it should be reading two.
      expect(page).to have_no_css("h2", text: /admin tools/i)
      expect(sidebar).to have_no_link("Players")
    end
  end

  context "when the server is offline" do
    before do
      service_api.server_connected = false
      service_api.administrator = true
    end

    it "says so and offers nothing to run, even to an administrator" do
      visit_dashboard

      expect(sidebar).to have_content("Offline")

      # Connectivity is checked after the allowlist, so this viewer clears every permission gate on the page and
      # still gets nothing. That ordering is what the empty state has to prove it respects.
      expect(page).to have_content("Nothing enabled here yet")
      expect(page).to have_no_content("SQF Console")
      expect(page).to have_no_content("Gamble")
    end
  end

  context "when the server is too old for these pages" do
    let(:server) { create(:server, community:, server_version: "2.0.0") }

    before do
      # The gate is never enforced locally, because a development extension reports whatever is currently built
      # rather than whatever was last released. Test counts as local, so the deny path only exists once it does not.
      allow(Rails.env).to receive(:local?).and_return(false)

      service_api.administrator = true
    end

    it "tells a player to wait and tells whoever can fix it what to fix" do
      visit_dashboard

      expect(page).to have_content("This server needs updating")
      expect(page).to have_content("#{server.server_id}'s admins need to update ESM")

      # Version numbers are for the person who can act on them, and this viewer cannot.
      expect(page).to have_no_content("These pages need #{ServerVersion::MINIMUM_SERVER_VERSION}")

      # The rail drops what an outdated server could not answer anyway, rather than offering a link into a failure.
      expect(sidebar).to have_no_link("My Player")

      service_api.modifiable_by = true
      visit_dashboard

      expect(page).to have_content("#{server.server_id} is on #{server.display_version}")
      expect(page).to have_content("These pages need #{ServerVersion::MINIMUM_SERVER_VERSION}")
    end
  end
end
