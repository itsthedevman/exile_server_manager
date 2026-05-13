# frozen_string_literal: true

#
# Establishes the ActiveRecord connection.
#
# Must run before Zeitwerk eager-loads anything: AR models touch the schema
# (`establish_connection`, column lookups, association reflection) at class
# definition time, so the connection has to exist by then.
#

require ESM.root.join("lib", "esm", "database.rb")

ESM::Database.connect!
