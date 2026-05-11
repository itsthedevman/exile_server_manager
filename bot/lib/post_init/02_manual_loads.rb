# frozen_string_literal: true

#
# Manually loads everything Zeitwerk can't (or shouldn't) own:
#
#   * `ApplicationRecord`: every AR model inherits from it, so it has to
#     exist before any model class is parsed. Zeitwerk would lazy-load it,
#     which is too late for the inheritance chain.
#   * Core gem internals: code lives outside this loader's root and would
#     never be picked up by the bot's Zeitwerk instance.
#   * `Command::Base` infrastructure: a tree of helpers whose layout doesn't
#     match Zeitwerk's "one file = one constant" rule.
#   * `ApplicationCommand`: base every Discord slash command inherits from.
#
# These same paths are added to Zeitwerk's ignore list in `03_zeitwerk.rb`
# so the autoloader doesn't trip over them.
#

require ESM.root.join("lib", "esm", "model", "application_record.rb")

Dir[ESM_CORE_PATH.join("lib", "**", "*.rb")].sort.each { |f| require f }

Dir[ESM.root.join("lib", "esm", "command", "base", "**", "*.rb")].sort.each { |f| require f }

require ESM.root.join("lib", "esm", "command.rb")
require ESM.root.join("lib", "esm", "command", "base.rb")
require ESM.root.join("lib", "esm", "model", "application_command.rb")
