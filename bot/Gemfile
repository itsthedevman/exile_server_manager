# frozen_string_literal: true

source "https://rubygems.org"

gem "actionview", "~> 7.0", ">= 7.0.7.2"
gem "activerecord", "~> 7.0", ">= 7.0.7.2"
gem "activerecord-import", "~> 1.5"
gem "activesupport", "~> 7.0", ">= 7.0.7.2"
gem "colorize"
gem "concurrent-ruby"
gem "discordrb", git: "https://github.com/itsthedevman/discordrb.git", branch: "fix/group-subcommand-mixing"
gem "dotenv"
gem "dotiw"
gem "everythingrb"
gem "fast_jsonparser"
gem "faye-websocket"
gem "httparty"
gem "i18n"
gem "openssl"
gem "pg"
gem "pry"
gem "puma"
gem "rake"
gem "redis"
gem "neatjson"
gem "semantic"
gem "standalone_migrations", "~> 7.1", ">= 7.1.1"
gem "steam_web_api"
gem "steam-condenser"
gem "sucker_punch"
gem "terminal-table"
gem "zeitwerk"

group :development do
  gem "active_record_query_trace"
  gem "awesome_print"
  gem "bcrypt_pbkdf"
  gem "benchmark-ips"
  gem "bundle-audit"
  gem "bundler"
  gem "capistrano-asdf"
  gem "capistrano-bundler"
  gem "capistrano"
  gem "ed25519"
  gem "factory_bot"
  gem "faker"
  gem "memory_profiler"
  gem "ruby-prof"
  gem "solargraph"
  gem "standard"
  gem "rubocop-rspec"
  gem "rubocop-performance"
  gem "rubocop-rails"
end

group :test do
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
  gem "timecop"
  gem "mysql2"
  gem "hashids"
end

group :development, :test do
  gem "rspec"
  gem "rspec-wait"
end

group :development, :documentation do
  gem "yard"
  gem "kramdown"
end
