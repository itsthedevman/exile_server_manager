# frozen_string_literal: true

#
# Loads the shared ESM core gem from its in-monorepo path. This is what
# first defines `module ESM`; the bot reopens it in `lib/esm.rb` to add
# its own API.
#

require ESM_CORE_PATH.join("lib", "esm.rb")
