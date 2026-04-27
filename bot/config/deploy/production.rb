# frozen_string_literal: true

append :linked_files, ".env.prod"

role :app, %w[esm]

set :default_env, {
  RAILS_ENV: "production",
  ESM_ENV: "production",
  RACK_ENV: "production"
}

set :asdf_tools, %w[bundler ruby rust]
set :asdf_map_ruby_bins, %w[bundle gem]
