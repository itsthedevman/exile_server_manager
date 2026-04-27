# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Explicitly require core models
  core_path =
    if (path = ENV["ESM_RUBY_PATH"]) && path.present?
      Pathname.new(path)
    else
      Pathname.new(File.expand_path("../../../", __dir__)).join("esm_ruby_core")
    end

  Dir[core_path.join("lib/**/*.rb")].sort.each do |file|
    load file
  end

  # Now load website extensions
  Dir[Rails.root.join("app/models/esm/**/*.rb")].sort.each do |file|
    load file
  end

  load Rails.root.join("app/models/esm.rb")
end
