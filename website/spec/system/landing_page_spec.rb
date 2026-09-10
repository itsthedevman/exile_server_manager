# frozen_string_literal: true

require "system_helper"

# The smoke test for the harness itself. It asserts almost nothing about the product on purpose: if this fails,
# the browser, the driver, or the in-process server is broken rather than the page.
RSpec.describe "The landing page", type: :system do
  it "renders and follows a link out" do
    visit root_path

    expect(page).to have_content("Management Platform")

    click_link "Get Started"

    expect(page).to have_current_path(getting_started_docs_path)
  end
end
