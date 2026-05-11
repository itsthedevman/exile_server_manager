# frozen_string_literal: true

require_relative ESM.root.join("lib", "esm", "database.rb")

ESM::Database.connect!
