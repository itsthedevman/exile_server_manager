# frozen_string_literal: true

rails_env = ENV.fetch("RAILS_ENV", "development")
app_directory = File.expand_path("../..", __FILE__)
tmp_directory = "#{app_directory}/tmp"

# Enable fork_worker for better memory efficiency (Puma 5+)
# This creates a "refork" master that can be used to spawn workers faster
if rails_env == "production" && respond_to?(:fork_worker)
  fork_worker
end

preload_app!

# Match CPU cores
workers ENV.fetch("WEB_CONCURRENCY", 4)

worker_timeout 60

# Better connection management
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

before_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

if rails_env == "development"
  max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
  min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count)
  port ENV.fetch("PORT", 3000)
else
  min_threads_count = ENV.fetch("RAILS_MIN_THREADS", 2)
  max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 8)

  # Unix socket for nginx
  bind "unix://#{tmp_directory}/sockets/puma.sock"

  # Logging
  stdout_redirect "/opt/esm_website/shared/log/puma.stdout.log",
    "/opt/esm_website/shared/log/puma.stderr.log",
    true

  # PID management
  pidfile "#{tmp_directory}/pids/puma.pid"
  state_path "#{tmp_directory}/pids/puma.state"

  # Enable control app on a unix socket (more secure than TCP)
  activate_control_app "unix://#{tmp_directory}/sockets/pumactl.sock"

  # Add some reliability features
  worker_check_interval 5
  worker_shutdown_timeout 30

  # Helps with memory bloat over time
  worker_boot_timeout 60
end

threads min_threads_count, max_threads_count
environment rails_env

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart
