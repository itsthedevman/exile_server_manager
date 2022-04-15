namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do |host|
      eye_executable = "/home/wolf/.rbenv/shims/eye"

      execute("cd /home/wolf/esm_bot/current && #{eye_executable} stop esm && #{eye_executable} load bin/prod.eye && #{eye_executable} start esm")
      info("Restarted ESM")
    end
  end
end
