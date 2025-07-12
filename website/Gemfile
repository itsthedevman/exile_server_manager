source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"

####################################################################################################
## Groups
####################################################################################################

group :development, :test do
  # Debugging support
  gem "pry"
  gem "pry-remote"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Deployment tools
  gem "capistrano", require: false
  gem "capistrano-asdf", require: false
  gem "capistrano-bundler", require: false
  gem "capistrano-rails", require: false
  gem "capistrano-yarn", require: false

  # Code formatting and linting
  gem "standard"
  gem "rubocop-performance"
  gem "rubocop-rails"
  gem "rubocop-rspec"

  # Profiling and debugging
  gem "rack-mini-profiler"
  gem "htmlbeautifier"

  # SSH and encryption dependencies for Capistrano
  gem "ed25519", require: false
  gem "bcrypt_pbkdf", require: false
end

####################################################################################################

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Markdown parsing
gem "kramdown"
gem "kramdown-parser-gfm"

# Utilities and helpers
gem "sortsmith"
gem "everythingrb"
gem "arel-helpers"

# Authentication
gem "devise", "~> 4.9"

# Authorization
gem "pundit", "~> 2.5"

# Asset/Javascript compilation
gem "vite_rails", "~> 3.0"

# Slim template engine for Rails views
gem "slim", "~> 5.2"
