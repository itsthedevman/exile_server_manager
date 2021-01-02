# config valid for current version and patch releases of Capistrano
lock "~> 3.14.1"

set :application, "esm_bot"
set :repo_url, "git@github.com:WolfkillArcadia/esm_bot.git"
set :deploy_to, "/home/wolf/esm_bot"

append :linked_dirs, ".bundle", "tmp"
