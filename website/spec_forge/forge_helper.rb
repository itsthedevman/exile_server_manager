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
    DatabaseCleaner.strategy = [:deletion, {except: %w[api_tokens]}]
    DatabaseCleaner.clean_with(:deletion, {except: %w[api_tokens]})
  end

  config.define_callback :prepare_database do |context|
    DatabaseCleaner.start
  end

  config.define_callback :cleanup_database do |context|
    DatabaseCleaner.clean
  end

  config.on_debug do
    puts "\n" + "=" * 80
    puts "🐛 DEBUG: #{expectation.name}"
    puts "=" * 80

    # Request details
    puts "\n📤 REQUEST:"
    puts "  Method: #{request.http_verb}"
    puts "  URL: #{request.base_url}#{request.url}"
    puts "  Headers: #{request.headers.to_h}"
    puts "  Query: #{request.query.to_h}"
    puts "  Body: #{request.body.to_h}" unless request.body.to_h.empty?

    # Response details
    puts "\n📥 RESPONSE:"
    puts "  Status: #{response.status} (expected: #{expected_status})"
    puts "  Headers: #{response.headers.slice("content-type", "location", "x-request-id")}"
    puts "  Body: #{JSON.pretty_generate(response.body)}" if response.body.is_a?(Hash)
    puts "  Body: #{response.body}" unless response.body.is_a?(Hash)

    # Variables context
    puts "\n🔧 VARIABLES:"
    variables.each { |k, v| puts "  #{k}: #{v.inspect}" }

    # Failure analysis
    if response.status != expected_status
      puts "\n❌ STATUS MISMATCH!"
      puts "  Expected: #{expected_status}"
      puts "  Got: #{response.status}"
      binding.pry
    end

    # JSON structure comparison on success
    if response.status == expected_status && expected_json.present?
      puts "\n✅ Status matches! JSON structure:"
      puts "  Expected: #{expected_json}"
      puts "  Actual keys: #{response.body.keys}" if response.body.is_a?(Hash)
    end

    puts inspect

    puts "=" * 80 + "\n"
  end
end
