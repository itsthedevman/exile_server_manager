# frozen_string_literal: true

# Load Dotenv variables; overwriting any that already exist
Dotenv.overload
Dotenv.overload(".env.test") if ENV["ESM_ENV"] == "test"
Dotenv.overload(".env.production") if ENV["ESM_ENV"] == "production"
