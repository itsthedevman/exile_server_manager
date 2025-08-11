# frozen_string_literal: true

timer = Timer.start!

#############################
# Initializers
#############################

ESM.load! unless ESM.loader.setup? && ESM.loader.eager_loaded?

# I very must dislike this.
load ESM.root.join("lib", "esm", "model", "community.rb")
load ESM.root.join("lib", "esm", "model", "notification.rb")
load ESM.root.join("lib", "esm", "model", "request.rb")
load ESM.root.join("lib", "esm", "model", "server_reward.rb")
load ESM.root.join("lib", "esm", "model", "server.rb")
load ESM.root.join("lib", "esm", "model", "user.rb")

info!("Completed in #{timer.stop!}s")

trace!("Trace logging enabled")
debug!("Debug logging enabled")
