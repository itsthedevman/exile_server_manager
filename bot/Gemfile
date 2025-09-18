# frozen_string_literal: true

source "https://rubygems.org"

####################################################################################################
## Development & Test Groups
####################################################################################################

group :development, :test do
  # Testing framework
  gem "rspec"
  gem "rspec-wait"
end

group :development do
  # === Debugging & Profiling ===
  gem "awesome_print"                     # Pretty print objects
  gem "active_record_query_trace"         # See where SQL queries come from
  gem "memory_profiler"                   # Memory usage analysis
  gem "ruby-prof"                         # Performance profiling
  gem "benchmark-ips"                     # Iterations per second benchmarking

  # === Code Quality & Formatting ===
  gem "ruby-lsp"                          # VS Code Ruby support
  gem "solargraph"                        # Language server for IntelliSense
  gem "standard"                          # Ruby style guide enforcer
  gem "rubocop-performance"               # Performance-focused cops
  gem "rubocop-rails"                     # Rails-specific cops
  gem "rubocop-rspec"                     # RSpec best practices

  # === Deployment ===
  gem "capistrano", require: false
  gem "capistrano-asdf", require: false
  gem "capistrano-bundler", require: false

  # SSH dependencies for Capistrano
  gem "ed25519", require: false
  gem "bcrypt_pbkdf", require: false

  # === Security & Dependencies ===
  gem "bundle-audit"                      # Security vulnerability scanner
  gem "bundler"                           # Dependency management
  gem "factory_bot"                       # Test data factories
  gem "faker"                             # Fake data generation for tests
end

group :test do
  gem "database_cleaner-active_record"    # Clean test database between runs
  gem "simplecov", require: false         # Code coverage reporting
  gem "timecop"                           # Time travel for tests
  gem "mysql2"                            # MySQL support for testing
  gem "hashids"                           # Generate short unique IDs
end

group :development, :documentation do
  gem "yard"                              # Documentation generation
  gem "kramdown"                          # Markdown parser for docs
end

####################################################################################################
## Core Framework Components
####################################################################################################

# Rails components
gem "actionview"                          # View layer and helpers
gem "activerecord"                        # ORM and database abstraction
gem "activesupport"                       # Core extensions and utilities
gem "activerecord-import"                 # Bulk import for ActiveRecord

# Autoloading and dependency management
gem "zeitwerk"                            # Modern Ruby autoloader
gem "i18n"                                # Internationalization support

####################################################################################################
## Database & Storage
####################################################################################################

gem "pg"                                  # PostgreSQL adapter
gem "redis"                               # In-memory data store for caching/sessions
gem "otr-activerecord"                    # ActiveRecord without Rails
gem "standalone_migrations"               # Database migrations outside Rails

####################################################################################################
## Discord Bot Framework
####################################################################################################

gem "discordrb",                          # Discord integration (custom fork with subcommand fixes)
  git: "https://github.com/itsthedevman/discordrb.git",
  branch: "fix/group-subcommand-mixing"
gem "faye-websocket"                      # WebSocket client

####################################################################################################
## External APIs & Integrations
####################################################################################################

# Steam platform integration
gem "steam_web_api"                       # Official Steam Web API wrapper
gem "steam-condenser"                     # Steam server queries and RCON

# HTTP client
gem "httparty"                            # Simple HTTP requests

####################################################################################################
## Background Jobs & Async Processing
####################################################################################################

gem "concurrent-ruby"                     # Thread-safe concurrency primitives
gem "sucker_punch"                        # Asynchronous processing using Celluloid

####################################################################################################
## Utilities & Parsing
####################################################################################################

# JSON processing
gem "fast_jsonparser"                     # Fast JSON parsing
gem "neatjson"                            # Pretty JSON formatting

# Data processing & formatting
gem "semantic"                            # Semantic versioning helper
gem "dotiw"                               # Distance of time in words

# Configuration & Environment
gem "dotenv"                              # Environment variable management
gem "openssl"                             # SSL/TLS support

# CLI & Output
gem "colorize"                            # Colorized terminal output
gem "terminal-table"                      # ASCII tables for CLI

# Debugging
gem "pry"                               # Interactive debugging console

####################################################################################################
## Web Server & Core Infrastructure
####################################################################################################

gem "puma"                                # Multi-threaded web server
gem "rake"                                # Ruby build tool

####################################################################################################
## Custom Libraries
####################################################################################################

gem "esm_ruby_core",                      # ESM core functionality
  path: "../esm_ruby_core"
gem "everythingrb"                        # Method extensions and utilities
