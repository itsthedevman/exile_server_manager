# frozen_string_literal: true

timer = Timer.start!

#############################
# Initializers
#############################

ESM.load! unless ESM.loader.setup? && ESM.loader.eager_loaded?

# Load the overwrites
Dir[ESM_CORE_PATH.join("esm", "models", "*.rb")]
  .map { |path| File.basename(path, "*.rb") }
  .map { |filename| ESM.root.join("lib", "esm", "model", filename) }
  .select(&:exist?)
  .each { |path| load path }

trace!("Trace logging enabled")
debug!("Debug logging enabled")

info!("Completed in #{timer.stop!}s")
