namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do |host|
      execute("source /home/wolf/.nvm/nvm.sh && cd /home/wolf/esm_bot/current && source .env.prod && /home/wolf/.rbenv/shims/eye load bin/prod.eye && /home/wolf/.rbenv/shims/eye restart esm")
      info("Restarted ESM")
    end
  end
end
