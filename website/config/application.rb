require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EsmWebsiteV2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # Ignore omniauth directory since we manually require the vendored strategy
    config.autoload_lib(ignore: %w[assets tasks omniauth])

    # The whole ESM namespace is loaded once by config/initializers/esm.rb: core
    # (re-opened by app/models/esm/*) plus the website-native ESM::Service::API in
    # lib/esm. Keep every ESM-defining path out of the reloadable autoloader. If
    # Zeitwerk owns the ESM namespace, a dev reload unloads it (taking all of core
    # with it), so the next request NameErrors until a full reboot. Ignored here +
    # loaded manually there = ESM survives reloads while the rest of the app still
    # hot-reloads.
    %w[app/models/esm.rb app/models/esm lib/esm].each do |path|
      Rails.autoloaders.main.ignore(File.expand_path("../#{path}", __dir__))
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Set the default URL options
    routes.default_url_options = {
      host: Rails.env.production? ? "esmbot.com" : "localhost:3000",
      protocol: Rails.env.production? ? "https" : "http"
    }
  end
end
