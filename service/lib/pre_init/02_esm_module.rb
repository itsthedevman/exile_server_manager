# frozen_string_literal: true

#
# Bootstraps the `ESM` module. Loads the bare module definition, the
# styled `ESM::Logger`, and installs `Kernel#info!` / `#debug!` / etc.
# so the rest of boot can log via the module-level shorthands.
#
# The bot reopens `module ESM` in `lib/esm.rb` to layer on its own API.
#

Loader.file("core", "lib", "esm.rb")
Loader.file("core", "lib", "esm", "logger.rb")

ESM::Logger.define_global_methods!
