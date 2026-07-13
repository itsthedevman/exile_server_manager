# frozen_string_literal: true

require "rails_helper"

##
# Guards the ESM-namespace loading strategy set up in config/application.rb and
# config/initializers/esm.rb: the whole ESM namespace (core, the app/models/esm re-opens, and the
# website-native lib/esm code) is loaded ONCE and kept out of Rails' reloadable main autoloader.
#
# The moment a file in a reloadable autoload path defines a constant under ESM, Zeitwerk's main
# autoloader claims the ESM namespace as its own and tears it down on every code reload. Core's
# once-loaded classes go with it, so the next request NameErrors until a full reboot (classically
# Devise's route redraw: uninitialized constant ESM::User). Such a path shows up here as a non-nil
# expected cpath equal to "ESM" or nested under it. Ignored paths report nil and are skipped.
RSpec.describe "ESM namespace reload isolation" do
  let(:main) { Rails.autoloaders.main }

  # Every Ruby file the reloadable autoloader would manage, paired with the constant Zeitwerk
  # expects there. Only files matter: an empty `esm/` directory maps to the cpath "ESM" but is
  # harmless, since Zeitwerk never materializes an implicit namespace with no files under it.
  # Nested roots (e.g. app/models and app/models/concerns) overlap, so uniq.
  let(:managed_cpaths) do
    main.dirs.flat_map do |root|
      Dir.glob(File.join(root, "**", "*.rb")).filter_map do |path|
        cpath = main.cpath_expected_at(path)
        [path, cpath] if cpath
      end
    end.uniq
  end

  it "has no reloadable path defining a constant under ESM" do
    offenders = managed_cpaths.select do |_path, cpath|
      cpath == "ESM" || cpath.start_with?("ESM::")
    end

    expect(offenders).to be_empty, <<~MESSAGE
      Reloadable autoload path(s) define a constant under ESM:

      #{offenders.map { |path, cpath| "  #{cpath}  <-  #{path}" }.join("\n")}

      The whole ESM namespace must load once (config/initializers/esm.rb) and stay out of the
      reloadable autoloader, or a code reload unloads ESM and the next request NameErrors (e.g.
      Devise's ESM::User route redraw). Move this into lib/esm/ (already ignored and manually
      loaded) or give it a non-ESM namespace.
    MESSAGE
  end
end
