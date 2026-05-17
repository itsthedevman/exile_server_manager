# frozen_string_literal: true

#
# Loads the rest of core/lib that wasn't pulled in earlier (extensions,
# utilities, and the logger live in pre_init). Three things to load here:
#
#   1. ApplicationRecord, the parent of every model
#   2. The non-command bulk of esm/
#   3. The command framework, via Loader.load_commands
#
# This runs in post_init because models need the AR connection that
# `01_database.rb` establishes one step earlier.
#

Loader.file("core", "lib", "esm", "application_record.rb")

Loader.dir("core", "lib", "esm",
  except: [
    "/command/",
    "/application_record.rb",
    "/application_command.rb",
    "/logger.rb"
  ])

Loader.load_commands
