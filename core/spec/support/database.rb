# frozen_string_literal: true

require "active_record"

# Connect to the esm_ruby_core_test database
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  encoding: "unicode",
  pool: 5,
  host: ENV.fetch("POSTGRES_HOST", "localhost"),
  port: ENV.fetch("POSTGRES_PORT", "5432"),
  database: ENV.fetch("POSTGRES_DATABASE", "esm_ruby_core_test"),
  username: ENV.fetch("POSTGRES_USERNAME", "esm"),
  password: ENV.fetch("POSTGRES_PASSWORD", "password12345")
)

# Define ApplicationRecord for models to inherit from
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
