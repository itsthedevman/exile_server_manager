# frozen_string_literal: true

require Pathname.new(ENV.fetch("ESM_CORE_PATH")).join("lib", "loader.rb")

I18n.load_path += Dir[Loader.core_path.join("config", "locales", "**", "*.yml")]
I18n.reload!

Rails.application.config.after_initialize do
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
