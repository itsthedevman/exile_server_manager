# frozen_string_literal: true

require "rails_helper"

RSpec.describe "communities/servers/config", type: :view do
  let(:server) { create(:server) }
  let(:settings) { server.server_setting.attributes.with_indifferent_access }

  subject(:config) do
    render(template: "communities/servers/config", formats: [:yaml], locals: {server:, settings:})
    rendered
  end

  # The auto-updater has not shipped. Until it does its keys stay out of generated configs, so an owner never sees
  # options for something their server cannot do. Omitting them is safe on its own terms: every one of them has a
  # default the updater falls back to when the key is absent.
  describe "the auto-updater settings" do
    let(:updater_keys) { %w[updater_enabled updater_timeout_ms updater_log_path] }

    it "are written when the feature is visible" do
      allow(Rails.env).to receive(:local?).and_return(true)

      expect(config).to include(*updater_keys)
    end

    it "are left out entirely everywhere else" do
      allow(Rails.env).to receive(:local?).and_return(false)

      updater_keys.each { |key| expect(config).not_to include(key) }
    end
  end

  it "always writes the settings that have shipped" do
    allow(Rails.env).to receive(:local?).and_return(false)

    expect(config).to include("number_locale", "server_mod_name", "log_level")
  end
end
