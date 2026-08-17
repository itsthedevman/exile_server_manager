# frozen_string_literal: true

require "rails_helper"

RSpec.describe "docs/server_setup", type: :view do
  subject(:page) do
    render(template: "docs/server_setup")
    rendered
  end

  # The updater has not shipped, so the guide does not describe it. The toggle it tells owners to use is gated the
  # same way, and documenting a control nobody can see is worse than saying nothing.
  describe "the automatic updates section" do
    it "is written when the feature is visible" do
      allow(Rails.env).to receive(:local?).and_return(true)

      expect(page).to include("Automatic Updates", "esm_updater")
    end

    it "is left out entirely everywhere else" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(page).not_to include("Automatic Updates", "esm_updater")
    end
  end

  it "always renders the setup steps that have shipped" do
    allow(Rails.env).to receive(:local?).and_return(false)

    expect(page).to include("Discord Setup", "Server Installation", "Test Everything")
  end
end
