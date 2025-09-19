# frozen_string_literal: true

namespace :deploy do
  after :finished, :restart do
    on roles(:web) do
      execute("~/scripts/restart_website")
    end
  end
end
