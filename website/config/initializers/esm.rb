# frozen_string_literal: true

#
# Eager-loads core/lib into the Rails app. The website doesn't run Discord
# commands, so the entire `core/lib/esm/command/` tree is skipped; pulling
# it in would force discordrb just to satisfy class-level argument resolution.
#
# Uses `method: :load` (not :require) so Rails to_prepare reload semantics
# work in development.
#

require Pathname.new(ENV.fetch("ESM_CORE_PATH")).join("lib", "loader.rb")

Rails.application.config.to_prepare do
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

  # Website-side overrides that re-open core's AR classes to add
  # Discord/Rails-aware methods.
  Loader.dir("website", "app", "models", "esm", method: :load)
  Loader.file("website", "app", "models", "esm.rb", method: :load)
end
