# frozen_string_literal: true

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
#
esm_env = ENV.fetch("ESM_ENV", "development")
app_directory = File.expand_path("../..", __FILE__)
tmp_directory = "#{app_directory}/tmp"

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
preload_app!

# Change to match your CPU core count
workers 4
worker_timeout 3600

on_worker_boot do
  ESM::Database.connect!
end

if esm_env == "development"
  max_threads_count = 5
  min_threads_count = 5
else
  min_threads_count = 1
  max_threads_count = 6

  # Set up socket location
  bind "unix://#{tmp_directory}/sockets/puma.sock"

  # Logging
  stdout_redirect "#{app_directory}/log/puma.stdout.log", "#{app_directory}/log/puma.stderr.log", true

  # Set master PID and state locations
  pidfile "#{tmp_directory}/pids/puma.pid"
  state_path "#{tmp_directory}/pids/puma.state"
  activate_control_app
end

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch("API_PORT")

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
threads min_threads_count, max_threads_count

# Set the environment
environment esm_env
