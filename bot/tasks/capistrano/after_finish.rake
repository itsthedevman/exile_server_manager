# frozen_string_literal: true

namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do
      execute("sudo /bin/systemctl restart esm_bot.service")
      info("Restarted esm_bot")
    end
  end
end
