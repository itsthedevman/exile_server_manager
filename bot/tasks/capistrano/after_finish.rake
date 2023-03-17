namespace :deploy do
  after :finished, :restart_bot do
    on roles(:app) do |_host|
      info("Restarted ESM")
    end
  end
end
