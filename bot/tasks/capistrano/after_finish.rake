# frozen_string_literal: true

namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do
      execute("sudo /bin/systemctl restart esm_bot.service")

      # The API needs to reconnect
      execute("sudo /bin/systemctl restart esm_website.service")

      info("Restarted esm_bot")
    end
  end
end
