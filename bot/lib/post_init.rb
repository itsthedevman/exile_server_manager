# frozen_string_literal: true

timer = Timer.start!

#############################
# Initializers
#############################

ESM.load! unless ESM.loader.setup? && ESM.loader.eager_loaded?

info!("Completed in #{timer.stop!}s")

trace!("Trace logging enabled")
debug!("Debug logging enabled")
