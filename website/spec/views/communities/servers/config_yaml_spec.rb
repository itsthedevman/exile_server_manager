# frozen_string_literal: true

require "rails_helper"

RSpec.describe "communities/servers/config", type: :view do
  let(:server) { create(:server) }
  let(:settings) { server.server_setting.attributes.with_indifferent_access }

  subject(:config) do
    render(template: "communities/servers/config", formats: [:yaml], locals: {server:, settings:})
    rendered
  end

  # The auto-updater has not shipped. Until it does the key stays out of generated configs, so an owner never sees an
  # option for something their server cannot do. Omitting it is safe on its own terms: a missing key reads as enabled,
  # which is the value this would have written.
  describe "the auto-updater setting" do
    it "is written when the feature is visible" do
      allow(Rails.env).to receive(:local?).and_return(true)

      expect(config).to include("updater_enabled")
    end

    it "is left out entirely everywhere else" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(config).not_to include("updater_enabled")
    end
  end

  it "always writes the settings that have shipped" do
    allow(Rails.env).to receive(:local?).and_return(false)

    expect(config).to include("number_locale", "server_mod_name", "log_level")
  end
end
