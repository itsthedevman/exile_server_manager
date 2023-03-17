# config valid for current version and patch releases of Capistrano
lock "~> 3.15"

set :application, "esm_bot"
set :repo_url, "esm_bot:itsthedevman/esm_bot.git"
set :deploy_to, "/home/esm/esm_bot"

append :linked_dirs, ".bundle", "tmp", "log"
set :branch, "main"
