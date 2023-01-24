# config valid for current version and patch releases of Capistrano
lock "~> 3.15"

set :application, "esm_bot"
set :repo_url, "esm_bot:WolfkillArcadia/esm_bot.git"
set :deploy_to, "/home/wolf/esm_bot"

append :linked_dirs, ".bundle", "tmp", "log"
set :rbenv_ruby, "2.7.6"
set :branch, "main"

namespace :deploy do
  Rake::Task["deploy:compile_assets"].clear_actions
  task compile_assets: [:set_rails_env] do
    run_locally do
      if capture("git --no-pager diff #{fetch(:previous_revision)} #{fetch(:current_revision)} app/assets vendor/assets").empty?
        info "Skipping assets compilation"
      else
        invoke "deploy:assets:precompile"
        invoke "deploy:assets:backup_manifest"
      end
    end
  end
end
