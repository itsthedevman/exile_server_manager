namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do |host|
      execute("pm2 reload ecosystem.config.js --env production")
      info("Restarted ESM")
    end
  end
end
