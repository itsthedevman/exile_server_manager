# frozen_string_literal: true

RSpec.describe "communities/servers/config", type: :view do
  let(:server) { create(:server) }
  let(:settings) { server.server_setting.attributes.with_indifferent_access }

  subject(:config) do
    render(template: "communities/servers/config", formats: [:yaml], locals: {server:, settings:})
    rendered
  end

  it "writes the general settings" do
    expect(config).to include("number_locale", "server_mod_name", "log_level")
  end

  it "writes the auto-updater settings" do
    expect(config).to include("updater_enabled", "updater_timeout_ms", "updater_log_path")
  end
end
