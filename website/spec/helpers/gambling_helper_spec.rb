# frozen_string_literal: true

RSpec.describe GamblingHelper, type: :helper do
  describe "#gamble_leader_holder" do
    let(:server) { create(:server) }
    let(:holder) { create(:user) }
    let(:stat) { ESM::UserGambleStat.create!(user_id: holder.id, server_id: server.id, total_wins: 3) }

    # command_accessible? comes from the controller, which a helper spec does not have
    def viewer_can_run_info(allowed)
      helper.define_singleton_method(:command_accessible?) { |_command_name| allowed }
    end

    it "names the holder by their Steam name" do
      viewer_can_run_info(false)
      holder.user_steam_data.update!(username: "SteamDave")

      expect(helper.gamble_leader_holder(stat)).to eq("SteamDave")
    end

    it "shows a nameless holder's Steam UID to a viewer who can run info" do
      viewer_can_run_info(true)

      expect(helper.gamble_leader_holder(stat)).to eq(holder.steam_uid)
    end

    # Everyone who can gamble sees the leaderboard, and a UID is an identifier they have no reason to collect
    it "keeps a nameless holder's Steam UID from everyone else" do
      viewer_can_run_info(false)

      expect(helper.gamble_leader_holder(stat)).to eq("Unknown player")
    end

    it "marks an unclaimed record" do
      expect(helper.gamble_leader_holder(nil)).to eq("—")
    end
  end
end
