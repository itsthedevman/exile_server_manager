# frozen_string_literal: true

set :branch, :main

server "127.0.0.1",
  user: "deploy",
  roles: %w[app db web],
  ssh_options: {
    port: 2223,
    keys: %w[~/.ssh/id_ed25519],
    forward_agent: true,
    auth_methods: %w[publickey],
    user_known_hosts_file: "/dev/null"
  }

# Development-specific settings
set :log_level, :debug
set :pty, true
