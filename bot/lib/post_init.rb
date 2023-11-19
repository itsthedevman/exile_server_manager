# frozen_string_literal: true

timer = Timer.start!

ESM.load! unless ESM.loader.setup? && ESM.loader.eager_loaded?

#############################
# Initializers
#############################
ESM::Arma::ClassLookup.cache

info!("Completed in #{timer.stop!}s")
