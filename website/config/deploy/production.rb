append :linked_files, ".env.prod"

role :web, %w[esm]

set :default_env, {
  RAILS_SERVE_STATIC_FILES: true
}

set :branch, :main
