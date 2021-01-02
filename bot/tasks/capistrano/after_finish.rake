namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do |host|
      execute("source /home/wolf/.nvm/nvm.sh && cd /home/wolf/esm_bot/current && source .env.prod && pm2 reload ecosystem.config.js --env production")
      info("Restarted ESM")
    end
  end
end
