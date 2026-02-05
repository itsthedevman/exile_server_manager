source "https://rubygems.org"

# Core Rails framework
gem "rails", "~> 8.0.2"

####################################################################################################
## Development & Test Groups
####################################################################################################

group :development, :test do
  # Interactive debugging console
  gem "pry"
  gem "pry-remote"

  # Security vulnerability scanner
  gem "brakeman", require: false
end

group :development do
  # === Debugging & Profiling ===
  gem "web-console"             # Better error pages with REPL
  gem "rack-mini-profiler"      # Performance profiling toolbar
  gem "benchmark-ips"           # Iterations per second benchmarking

  # === Code Quality & Formatting ===
  gem "ruby-lsp"                # VS Code Ruby support
  gem "standard"                # Ruby style guide enforcer
  gem "rubocop-performance"     # Performance-focused cops
  gem "rubocop-rails"           # Rails-specific cops
  gem "rubocop-rspec"           # RSpec best practices
  gem "htmlbeautifier"          # HTML/ERB formatter
end

group :test do
  gem "database_cleaner-active_record"
  gem "rspec-rails"
  gem "webmock"
end

####################################################################################################
## Core Infrastructure
####################################################################################################

# Database
gem "pg"                        # PostgreSQL adapter

# Web Server
gem "puma"                      # Multi-threaded web server
gem "thruster", require: false  # HTTP/2, caching, compression layer for Puma

# Caching & Background Jobs (Solid* suite - DB-backed adapters)
gem "solid_cache"               # Database-backed Rails.cache
gem "solid_queue"               # Database-backed Active Job
gem "solid_cable"               # Database-backed Action Cable

# Performance
gem "bootsnap", require: false  # Faster boot through caching

# Communication
gem "drb" # Distributed Ruby (DRb) for remote object communication

####################################################################################################
## Frontend & Assets
####################################################################################################

# Asset Pipeline
gem "propshaft"                 # Modern asset pipeline (simpler than Sprockets)
gem "vite_rails"                # Vite integration for JS/CSS bundling
gem "sass-embedded"             # Dart Sass for stylesheets

# Hotwire Stack
gem "turbo-rails"               # SPA-like navigation without the complexity
gem "stimulus-rails"            # Modest JavaScript framework

# View Layer
gem "slim"                      # Cleaner template syntax than ERB
gem "view_component"            # Encapsulated, testable view components

# Content Processing
gem "kramdown"                  # Markdown to HTML converter
gem "kramdown-parser-gfm"       # GitHub Flavored Markdown support

####################################################################################################
## Authentication & Authorization
####################################################################################################

gem "devise"                    # Complete authentication solution
gem "pundit"                    # Simple, robust authorization

# OAuth Providers
gem "omniauth"
gem "omniauth-openid"
gem "omniauth-rails_csrf_protection"
gem "omniauth-discord"
# omniauth-steam is handled by lib/omniauth/strategies/steam.rb --- the gem has a bug with multi-json (as of 2026-02)

####################################################################################################
## Utilities & Custom
####################################################################################################

# External Dependencies
gem "http"                      # Clean HTTP client
gem "semantic"                  # Semantic versioning helper
gem "faker"                     # Fake data generation
gem "dotenv"                    # Environment variable management
gem "ostruct"                   # OpenStruct for dynamic objects
gem "config"                    # YAML based configuration
gem "dry-validation"

# My Libraries
gem "esm_ruby_core", path: "../esm_ruby_core"
gem "everythingrb"              # Method extensions
gem "sortsmith"                 # Sorting utilities
gem "spec_forge"                # API testing suite
