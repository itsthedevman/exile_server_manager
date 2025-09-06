# frozen_string_literal: true

##########################################
# Framework Integration
##########################################

require_relative "../config/environment"
require "database_cleaner/active_record"

##########################################
# Configuration
##########################################

# Load or create the API token. This way I don't have to manage it manually
def load_api_token
  api_token = ESM::ApiToken.all.pick(:token)
  return api_token if api_token.present?

  ESM::ApiToken.create!(comment: "api testing").token
end

# Configure SpecForge
SpecForge.configure do |config|
  config.base_url = "http://localhost:3000/api/v1"

  config.rspec.formatter = :documentation

  config.headers = {
    "Authorization" => "Bearer #{load_api_token}"
  }

  config.rspec.before(:suite) do
    DatabaseCleaner.strategy = [:deletion]
    DatabaseCleaner.clean_with(:deletion)
  end

  config.rspec.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
