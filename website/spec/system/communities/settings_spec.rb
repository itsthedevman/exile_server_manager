# frozen_string_literal: true

require "system_helper"

# The other half of the permission story. The dashboard hides things a viewer may not use; this page is the case where
# not having the permission means the page itself is not there, and the two are different code paths: one is a template
# asking `command_accessible?`, the other is a `before_action` that raises before any template runs.
#
# Which entries the rail carries is a second axis with nothing to do with permission - a player community has no
# servers, no commands and no notifications to configure, so those entries would lead nowhere - and the two are worth
# holding apart, because a page that hid the wrong half of the rail would look identical to one denying access.
RSpec.describe "Community settings", type: :system do
  let(:owner) { create(:user) }
  let(:user) { create(:user) }

  # Said out loud because the model defaults the other way: a community built without this is a player community, and
  # a player community is missing most of what this page and its rail carry. Every example below wants a server
  # community except the one that says otherwise.
  let(:community) { create(:community, owner_user_id: owner.id, player_mode_enabled: false) }

  before { login_as(user, scope: :user) }

  def visit_settings
    visit edit_community_path(community.public_id)
  end

  def sidebar
    find("#dashboard-sidebar")
  end

  context "when the viewer cannot manage the community" do
    it "does not have the page at all" do
      visit_settings

      expect(page).to have_content("404 - Not Found")

      # Not the same claim as the 404 above. The gate raising and the template rendering nothing would both leave a
      # page with no form on it, and only one of those is the page refusing to exist.
      expect(page).to have_no_content("Community Settings")
      expect(page).to have_no_css("#dashboard-sidebar")
    end
  end

  context "when the viewer can manage the community but does not own it" do
    before { service_api.modifiable_by = true }

    it "opens the settings and locks the one control that belongs to the owner" do
      visit_settings

      expect(page).to have_content("Community Settings")
      expect(page).to have_content("Only the community owner can change this.")

      # The modal is not rendered at all when the control is locked, so a button appearing here would not just be a
      # cosmetic slip; it would open a dialog that is not on the page.
      expect(page).to have_no_css("#change-mode-modal", visible: :all)

      # Management rights are what the rail is built from, and this viewer has them.
      expect(sidebar).to have_link("Commands")
      expect(sidebar).to have_link("Notifications")
      expect(sidebar).to have_link("Register New Server")
    end
  end

  context "when the viewer owns the community" do
    let(:user) { owner }

    before { service_api.modifiable_by = true }

    it "is offered the switch, and loses it once there is something to give up" do
      visit_settings

      expect(page).to have_css("#change-mode-modal", visible: :all)
      expect(page).to have_no_content("Only the community owner can change this.")

      # Player mode gives up server management, so it is only offered while the community has no servers to lose.
      # Same owner, same rights: the only thing that moved is what the community holds.
      create(:server, community:)
      visit_settings

      expect(page).to have_content("Remove this community's servers first")
      expect(page).to have_no_css("#change-mode-modal", visible: :all)
    end
  end

  context "when the community is in player mode" do
    let(:community) { create(:community, owner_user_id: owner.id, player_mode_enabled: true) }

    before { service_api.modifiable_by = true }

    it "drops the rail entries a player community has nothing to put behind" do
      visit_settings

      expect(page).to have_content("Community Settings")

      expect(sidebar).to have_no_link("Commands")
      expect(sidebar).to have_no_link("Notifications")
      expect(sidebar).to have_no_link("Register New Server")

      # What is left is what a player community still has: where its own notifications go, and these settings.
      expect(sidebar).to have_link("XM8 Routing")
      expect(sidebar).to have_link("Settings")
    end
  end
end
