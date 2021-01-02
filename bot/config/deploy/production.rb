append :linked_files, ".env.prod"

role :app, %w{wolf@esmbot.com}
set :default_env, {
  RAILS_ENV: "production",
  ESM_ENV: "production",
  RACK_ENV: "production"
}
