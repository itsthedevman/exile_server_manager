namespace :deploy do
  before :check, :update_env do
    on roles(:app) do |host|
      admin_directory = "/home/wolf/esm_bot_admin"

      # Make sure the folder exists and the code has been cloned
      if !File.directory?(admin_directory)
        execute("cd /home/wolf && git clone esm_bot_admin:WolfkillArcadia/esm_bot_admin.git")
      end

      # Pull any updates
      execute("cd /home/wolf/esm_bot_admin && git pull")

      # Copy the files to shared
      execute("ln -s /home/wolf/esm_bot_admin/env /home/wolf/esm_bot/shared/.env")
      execute("ln -s /home/wolf/esm_bot_admin/env.prod /home/wolf/esm_bot/shared/.env.prod")
    end
  end
end
