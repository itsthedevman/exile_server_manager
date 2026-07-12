# frozen_string_literal: true

require "active_record"

# Share the esm_test database; its schema is loaded by the service/website suites.
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  encoding: "unicode",
  # Roomy enough for the concurrency specs, which check out a connection per racing thread; ordinary examples use one.
  pool: 25,
  host: ENV.fetch("POSTGRES_HOST", "localhost"),
  port: ENV.fetch("POSTGRES_PORT", "5432"),
  database: ENV.fetch("POSTGRES_DATABASE", "esm_test"),
  username: ENV.fetch("POSTGRES_USERNAME", "esm"),
  password: ENV.fetch("POSTGRES_PASSWORD", "password12345")
)

# Define ApplicationRecord for models to inherit from
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
