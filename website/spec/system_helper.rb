# frozen_string_literal: true

require "rails_helper"
require "capybara/rspec"
require "capybara/playwright"

Capybara.server = :puma, {Silent: true}

# rails_helper's `webmock/rspec` blocks every real connection, and Capybara's own boot check is one: it polls
# /__identify__ on the server it just started. Allowing localhost gives that back without giving back the
# outbound calls webmock exists to catch here, which all go to Steam and Discord.
#
# Set at load rather than in a hook so it is in place before the first `page`, whoever touches it first.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Rails registers `:playwright` itself and its registration wins over a same-named `Capybara.register_driver`
  # block, so the launch options only survive if they arrive through `driven_by`.
  #
  # `playwright_cli_executable_path` is the load-bearing one. Unset, the gem falls back to `npx playwright`, which
  # resolves a different Playwright than the flake's and then asks for a browser revision the Nix bundle does not
  # contain. The `playwright` on PATH wraps the driver those browsers were built against. The gem and that driver
  # have to stay on the same minor; see the note in the Gemfile.
  config.before(:each, type: :system) do
    driven_by(
      :playwright,
      options: {
        browser_type: :chromium,
        playwright_cli_executable_path: "playwright",
        headless: true,
        args: ["--no-sandbox"]
      }
    )
  end

  # Devise's IntegrationHelpers sign in by driving the request stack directly, which a browser session never touches.
  # Warden's own test proxy is the browser-side equivalent, and it reaches the server because Capybara runs Puma in
  # this process rather than a separate one.
  config.include Warden::Test::Helpers, type: :system
  config.after(:each, type: :system) { Warden.test_reset! }

  # `service_api` and the stubs behind it come from rails_helper, which installs them for request specs too. They
  # reach the Puma thread serving the browser because rspec-mocks stubs are process-global.
end
