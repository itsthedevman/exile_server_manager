module ESM
  class Database
    def self.clean!
      ESM::Request.delete_all
      ESM::Pledge.delete_all
      ESM::ServerMod.delete_all
      ESM::ServerReward.delete_all
      ESM::ServerSetting.delete_all
      ESM::Territory.delete_all
      ESM::GambleStat.delete_all
      ESM::UserNotificationPreference.delete_all
      ESM::Cooldown.delete_all
      ESM::Notification.delete_all
      ESM::CommandConfiguration.delete_all
      ESM::Server.delete_all
      ESM::Community.delete_all
      ESM::User.delete_all
    end
  end
end
