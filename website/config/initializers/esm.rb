# frozen_string_literal: true

require Pathname.new(ENV.fetch("ESM_CORE_PATH")).join("lib", "loader.rb")

I18n.load_path += Dir[Loader.core_path.join("config", "locales", "**", "*.yml")]
I18n.reload!

# Load core through `to_prepare`, not `after_initialize`: Devise reloads routes inside its own
# `after_initialize` hook, and `devise_for :users, class_name: "ESM::User"` constantizes the model
# at route-draw time. `to_prepare` runs before that hook, so the model exists when routes are drawn.
# The guard loads core exactly once — `to_prepare` otherwise re-fires every development reload, and
# re-loading core re-stacks callbacks and AR subclasses.
core_loaded = false

Rails.application.config.to_prepare do
  next if core_loaded

  core_loaded = true

  Loader.load_rails_extensions(method: :load) # Must be before we load lib/esm/*

  Loader.file("core", "lib", "esm.rb", method: :load)
  Loader.dir("core", "lib", "extensions", method: :load)
  Loader.dir("core", "lib", "utilities", method: :load)
  Loader.file("core", "lib", "esm", "application_record.rb", method: :load)
  Loader.dir("core", "lib", "esm",
    method: :load,
    except: [
      "/command/",
      "/application_record.rb",
      "/application_command.rb"
    ])

  Loader.load_commands(method: :load)

  ESM::Command.load

  # Website-side overrides that re-open core's AR classes to add
  # Discord/Rails-aware methods.
  Loader.dir("website", "app", "models", "esm", method: :load)
  Loader.file("website", "app", "models", "esm.rb", method: :load)
end
