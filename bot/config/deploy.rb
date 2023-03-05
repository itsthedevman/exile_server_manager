# config valid for current version and patch releases of Capistrano
lock "~> 3.15"

set :application, "esm_bot"
set :repo_url, "esm_bot:itsthedevman/esm_bot.git"
set :deploy_to, "/home/wolf/esm_bot"

append :linked_dirs, ".bundle", "tmp", "log"
set :rbenv_ruby, "3.2.0"
set :branch, "main"
