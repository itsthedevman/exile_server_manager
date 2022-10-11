append :linked_files, ".env.prod"

role :app, %w{prod}
set :default_env, {
  RAILS_ENV: "production",
  ESM_ENV: "production",
  RACK_ENV: "production"
}
