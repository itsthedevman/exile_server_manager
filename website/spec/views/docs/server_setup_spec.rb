# frozen_string_literal: true

RSpec.describe "docs/server_setup", type: :view do
  subject(:page) do
    render(template: "docs/server_setup")
    rendered
  end

  it "renders the setup steps" do
    expect(page).to include("Discord Setup", "Server Installation", "Test Everything")
  end

  it "renders the automatic updates guide" do
    expect(page).to include("Automatic Updates", "esm_updater")
  end
end
