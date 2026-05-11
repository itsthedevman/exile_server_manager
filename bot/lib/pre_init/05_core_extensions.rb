# frozen_string_literal: true

#
# Loads bot-specific monkey-patches and extensions to core/discordrb types.
#
# These are loaded eagerly here (rather than via Zeitwerk) because they
# *reopen* existing classes instead of defining new ones. Zeitwerk's
# "one file = one constant" rule would otherwise raise on these paths,
# so `03_zeitwerk.rb` also adds them to the loader's ignore list.
#

Dir[ESM_BOT_PATH.join("lib", "esm", "extension", "**", "*.rb")].sort.each { |extension| require extension }
Dir[ESM_BOT_PATH.join("lib", "esm", "discord", "extension", "**", "*.rb")].sort.each { |extension| require extension }
