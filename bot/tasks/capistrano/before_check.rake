# frozen_string_literal: true

namespace :deploy do
  before :check, :update_env do
    on roles(:app) do |host|
      # Clone or pull esm_bot_admin
      admin_repo = "/$HOME/esm_bot_admin"

      if !test "[ -d #{admin_repo} ]"
        execute("cd $HOME && git clone esm_admin:itsthedevman/esm_bot_admin.git")
      end

      execute("cd #{admin_repo} && git pull")

      # Link env for production
      if !test "[ -d /$HOME/esm_bot/shared ]"
        execute("mkdir -p /$HOME/esm_bot/shared")
      end

      execute("ln -sf #{admin_repo}/env.prod /$HOME/esm_bot/shared/.env.prod")

      # Clone or pull esm_ruby_core
      core_repo = "$HOME/esm_bot/esm_ruby_core"

      if !test "[ -d #{core_repo} ]"
        execute("cd $HOME/esm_bot && git clone esm_core:itsthedevman/esm_ruby_core.git")
      end
      execute("cd #{core_repo} && git pull")
    end
  end
end
