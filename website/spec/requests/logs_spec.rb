# frozen_string_literal: true

# LogsController and LogEntriesController together: neither is an AuthenticatedController, and neither treats the
# community in the URL as an access boundary. Possession of the log's own uuid is the credential, the same link the
# Discord side hands out. There is no :log or :log_entry factory; both are built inline, since neither needs more than
# a couple of explicit attributes.
RSpec.describe "Logs", type: :request do
  def build_log(server: create(:server), user: create(:user), search_text: "player teleported")
    ESM::Log.create!(server:, user:, search_text:)
  end

  def build_entry(log, file_name: "server.log", entries: [])
    ESM::LogEntry.create!(log:, file_name:, entries:)
  end

  describe "LogsController#show" do
    it "renders for a signed-out visitor, the bearer-link design working as intended" do
      log = build_log
      build_entry(log)

      get "/communities/#{log.server.community.public_id}/logs/#{log.public_id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(log.search_text)
    end

    it "is not found once the link has expired" do
      log = build_log
      build_entry(log)
      log.update!(expires_at: 5.minutes.ago)

      get "/communities/#{log.server.community.public_id}/logs/#{log.public_id}"

      expect(response).to have_http_status(:not_found)
    end

    # Documents current behavior: the community segment is resolved only for the "back to community" chrome, never
    # checked against log.server.community. The log's own uuid is the actual authority.
    it "still renders when the community segment in the URL belongs to someone else" do
      log = build_log
      build_entry(log)
      unrelated_community = create(:community)

      get "/communities/#{unrelated_community.public_id}/logs/#{log.public_id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(log.search_text)
    end

    it "is not found when the community segment does not resolve to a community at all" do
      log = build_log
      build_entry(log)

      get "/communities/does-not-exist/logs/#{log.public_id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "LogEntriesController#show" do
    it "renders for a signed-out visitor on a non-expired log" do
      log = build_log
      entry = build_entry(log)

      get "/communities/#{log.server.community.public_id}/logs/#{log.public_id}/entries/#{entry.public_id}"

      expect(response).to have_http_status(:ok)
    end

    # HOLE / GAP from the audit (community_dashboard.md, LogEntriesController#show): LogsController#show enforces
    # the "link expires on <date>" promise via Log.active; this action never applies that filter at all, so an
    # entry stays reachable forever past the 1-day expiry the product tells the requester to expect.
    it "is not found once the parent log has expired" do
      pending("HOLE: log_entries#show never checks the parent log's expiry, unlike logs#show (audit decision 3)")

      log = build_log
      entry = build_entry(log)
      log.update!(expires_at: 5.minutes.ago)

      get "/communities/#{log.server.community.public_id}/logs/#{log.public_id}/entries/#{entry.public_id}"

      expect(response).to have_http_status(:not_found)
    end

    # Documents current behavior: the entry is found globally by its own public_id, with no reference to the log_id
    # or community_id segments in the URL at all.
    it "still renders when the log and community segments in the URL do not match the entry's own log" do
      log = build_log
      entry = build_entry(log)
      other_log = build_log
      build_entry(other_log)
      unrelated_community = create(:community)

      get "/communities/#{unrelated_community.public_id}/logs/#{other_log.public_id}/entries/#{entry.public_id}"

      expect(response).to have_http_status(:ok)
    end
  end
end
