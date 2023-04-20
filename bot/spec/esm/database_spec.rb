# frozen_string_literal: true

describe ESM::Database do
  it "is connected" do
    ESM::Database.connected?
  end

  describe "It deletes entries properly (FK check)" do
    let!(:user) { ESM::Test.user }
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }

    before do
      # Cooldown
      create_list(:cooldown, 10, user_id: user.id, server_id: server.id, community_id: community.id)

      # UserNotificationRoute
      10.times.each do |i|
        create(
          :user_notification_route,
          user_id: user.id,
          source_server_id: server.id,
          destination_community_id: community.id,
          channel_id: "1",
          notification_type: ESM::UserNotificationRoute::TYPES[i]
        )
      end

      # UserNotificationPreference
      create(:user_notification_preference, user_id: user.id, server_id: server.id)

      # UserGambleStat
      create(:user_gamble_stat, user_id: user.id, server_id: server.id)
    end

    it "fully deletes a community" do
      expect(ESM::CommandConfiguration.where(community_id: community.id).size).not_to be_zero
      expect(ESM::Cooldown.where(community_id: community.id).size).not_to be_zero
      expect(ESM::Notification.where(community_id: community.id).size).not_to be_zero
      expect(ESM::Server.where(community_id: community.id).size).not_to be_zero
      expect(ESM::UserNotificationRoute.where(destination_community_id: community.id).size).not_to be_zero

      community.destroy

      expect(ESM::CommandConfiguration.where(community_id: community.id).size).to be_zero
      expect(ESM::Cooldown.where(community_id: community.id).size).to be_zero
      expect(ESM::Notification.where(community_id: community.id).size).to be_zero
      expect(ESM::Server.where(community_id: community.id).size).to be_zero
      expect(ESM::UserNotificationRoute.where(destination_community_id: community.id).size).to be_zero
    end

    it "fully deletes a server" do
      # Log
      create(:log, requestors_user_id: user.id, server_id: server.id)

      expect(ESM::Cooldown.where(server_id: server.id).size).not_to be_zero
      expect(ESM::Log.where(server_id: server.id).size).not_to be_zero
      expect(ESM::ServerMod.where(server_id: server.id).size).not_to be_zero
      expect(ESM::ServerReward.where(server_id: server.id).size).not_to be_zero
      expect(ESM::ServerSetting.where(server_id: server.id).size).not_to be_zero
      expect(ESM::UserGambleStat.where(server_id: server.id).size).not_to be_zero
      expect(ESM::UserNotificationPreference.where(server_id: server.id).size).not_to be_zero
      expect(ESM::UserNotificationRoute.where(source_server_id: server.id).size).not_to be_zero

      server.destroy

      expect(ESM::Cooldown.where(server_id: server.id).size).to be_zero
      expect(ESM::Log.where(server_id: server.id).size).to be_zero
      expect(ESM::ServerMod.where(server_id: server.id).size).to be_zero
      expect(ESM::ServerReward.where(server_id: server.id).size).to be_zero
      expect(ESM::ServerSetting.where(server_id: server.id).size).to be_zero
      expect(ESM::UserGambleStat.where(server_id: server.id).size).to be_zero
      expect(ESM::UserNotificationPreference.where(server_id: server.id).size).to be_zero
      expect(ESM::UserNotificationRoute.where(source_server_id: server.id).size).to be_zero
    end

    it "fully deletes a user" do
      # Cooldown
      create(
        :cooldown,
        user_id: user.id,
        steam_uid: user.steam_uid,
        server_id: server.id,
        community_id: community.id
      )

      # Request
      create(:request, requestor_user_id: user.id, requestee_user_id: "")
      create(:request, requestor_user_id: "", requestee_user_id: user.id)

      expect(ESM::Cooldown.where(user_id: user.id, steam_uid: user.steam_uid).size).not_to be_zero
      expect(ESM::Cooldown.where(user_id: user.id).size).not_to be_zero
      expect(ESM::Request.where(requestee_user_id: user.id).size).not_to be_zero
      expect(ESM::Request.where(requestor_user_id: user.id).size).not_to be_zero
      expect(ESM::UserGambleStat.where(user_id: user.id).size).not_to be_zero
      expect(ESM::UserNotificationPreference.where(user_id: user.id).size).not_to be_zero
      expect(ESM::UserNotificationRoute.where(user_id: user.id).size).not_to be_zero

      user.destroy

      # Since a User has two unique IDs, cooldowns handles both.
      # Deletion of a user will cause the user_id to be nulled
      expect(ESM::Cooldown.where(user_id: user.id).size).to be_zero
      expect(ESM::Cooldown.where(steam_uid: user.steam_uid).size).not_to be_zero

      expect(ESM::Request.where(requestee_user_id: user.id).size).to be_zero
      expect(ESM::Request.where(requestor_user_id: user.id).size).to be_zero
      expect(ESM::UserGambleStat.where(user_id: user.id).size).to be_zero
      expect(ESM::UserNotificationPreference.where(user_id: user.id).size).to be_zero
      expect(ESM::UserNotificationRoute.where(user_id: user.id).size).to be_zero
    end
  end
end
