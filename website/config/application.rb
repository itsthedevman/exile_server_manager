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

    # The ESM namespace is owned by the explicit Loader chain in
    # config/initializers/esm.rb, which loads core's canonical models and the
    # website re-opens once at boot. Zeitwerk must not also manage these files:
    # the website re-opens core classes (one constant, two defining files), which
    # violates Zeitwerk's one-file-one-constant rule and makes hot reload wipe
    # then half-rebuild the namespace (ESM::User loses its table, ESM::Command
    # vanishes, etc). Ignoring keeps the constants alive across reloads.
    #
    # IpcClient (lib/ipc_client*) is a process-lifetime singleton: one cached
    # NATS connection with a background reader thread. It must NOT be reloadable,
    # or each hot reload orphans the connection (zombie reader thread, stale
    # subscriptions) and the next request/reply times out. It's required once at
    # boot in config/initializers/ipc_client.rb instead.
    Rails.autoloaders.main.ignore(
      Rails.root.join("app/models/esm.rb"),
      Rails.root.join("app/models/esm"),
      Rails.root.join("lib/ipc_client.rb"),
      Rails.root.join("lib/ipc_client")
    )

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
