# frozen_string_literal: true

#
# Eager-loads core/lib into the Rails app, including the command tree. The
# website doesn't execute commands (the service does), but it loads the command
# classes to introspect them: argument metadata for the generic command forms
# and web-eligibility checks. Class-level argument resolution used to force
# discordrb; that coupling was removed, so the tree now loads cleanly here.
#
# Uses `method: :load` (not :require) so Rails to_prepare reload semantics
# work in development.
#

require Pathname.new(ENV.fetch("ESM_CORE_PATH")).join("lib", "loader.rb")

I18n.load_path += Dir[Loader.core_path.join("config", "locales", "**", "*.yml")]
I18n.reload!

Rails.application.config.to_prepare do
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

  Loader.load_commands

  ESM::Command.load

  # Website-side overrides that re-open core's AR classes to add
  # Discord/Rails-aware methods.
  Loader.dir("website", "app", "models", "esm", method: :load)
  Loader.file("website", "app", "models", "esm.rb", method: :load)
end
