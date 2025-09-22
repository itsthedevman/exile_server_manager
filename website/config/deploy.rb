# frozen_string_literal: true

# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "esm_website"

set :repo_url, "deploy_esm_website:itsthedevman/esm_website.git"
set :branch, :main

set :deploy_to, "/opt/esm_website"
set :keep_releases, 5

set :rails_env, "production"

# Set up ASDF environment manually (bypassing capistrano-asdf gem as it doesn't support asdf 0.16+)
set :default_env, {
  path: "/home/esm_website/.asdf/shims:$PATH",
  rails_env: "production",
  asdf_data_dir: "/home/esm_website/.asdf",
  RAILS_SERVE_STATIC_FILES: true
}

append :linked_dirs,
  "log", "tmp/pids", "tmp/cache", "tmp/sockets",
  "vendor/bundle", "public/system", "public/uploads"

# Override SSHKit command mapping to use ASDF shims
SSHKit.config.command_map[:bundle] = "/home/esm_website/.asdf/shims/bundle"
SSHKit.config.command_map[:rake] = "/home/esm_website/.asdf/shims/rake"
SSHKit.config.command_map[:rails] = "/home/esm_website/.asdf/shims/rails"
