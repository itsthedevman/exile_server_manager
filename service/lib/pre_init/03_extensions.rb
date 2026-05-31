# frozen_string_literal: true

#
# Loads core's standalone utility classes and the monkey-patches it ships
# for Ruby's stdlib types. These are loaded eagerly here (rather than via
# Zeitwerk) because the extensions *reopen* existing classes, which violates
# Zeitwerk's "one file = one constant" rule. `03_zeitwerk.rb` correspondingly
# adds them to the loader's ignore list.
#
# Layout under core/lib:
#
#   extensions/   monkey-patches on Logger, Array, Integer, String
#   utilities/    standalone helper classes (Inquirer, Timer)
#

Loader.dir("core", "lib", "extensions")
Loader.dir("core", "lib", "utilities")

# Discord-specific extensions stay service-side.
Loader.dir("service", "lib", "esm", "discord", "extension")
