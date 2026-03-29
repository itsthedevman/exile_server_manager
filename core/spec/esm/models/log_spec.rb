# frozen_string_literal: true

require "timecop"

RSpec.describe ESM::Log do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, :with_setting, community: community) }
  let!(:user) { create(:user) }

  describe "scopes" do
    describe ".expired" do
      it "returns logs with expires_at in the past" do
        expired_log = create(:log, server: server, user: user)
        expired_log.update_column(:expires_at, 2.days.ago)

        active_log = create(:log, server: server, user: user)

        expect(described_class.expired).to include(expired_log)
        expect(described_class.expired).not_to include(active_log)
      end
    end

    describe ".active" do
      it "returns logs with expires_at in the future" do
        active_log = create(:log, server: server, user: user)

        expired_log = create(:log, server: server, user: user)
        expired_log.update_column(:expires_at, 2.days.ago)

        expect(described_class.active).to include(active_log)
        expect(described_class.active).not_to include(expired_log)
      end
    end
  end

  describe "callbacks" do
    describe "before_create :generate_uuid" do
      it "generates a UUID public_id on create" do
        log = create(:log, server: server, user: user)

        expect(log.public_id).to be_present
        expect(log.public_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end

      it "always generates a new UUID (overwrites any provided value)" do
        # Note: The callback always regenerates the UUID - this is by design
        existing_id = SecureRandom.uuid
        log = create(:log, server: server, user: user, public_id: existing_id)

        expect(log.public_id).to be_present
        expect(log.public_id).not_to eq(existing_id)
      end
    end

    describe "before_create :set_expiration_date" do
      it "sets expires_at to 1 day from now" do
        Timecop.freeze do
          log = create(:log, server: server, user: user)
          expected = 1.day.from_now.utc

          expect(log.expires_at).to be_within(1.second).of(expected)
        end
      end
    end
  end

  describe "#link" do
    let(:log) { create(:log, server: server, user: user) }

    it "returns localhost URL in test environment" do
      link = log.link

      expect(link).to include("localhost:3000")
      expect(link).to include(community.public_id)
      expect(link).to include(log.public_id)
    end

    it "includes community public_id in path" do
      expect(log.link).to include("/communities/#{community.public_id}/")
    end

    it "includes log public_id in path" do
      expect(log.link).to include("/logs/#{log.public_id}")
    end

    it "memoizes the result" do
      first_call = log.link
      second_call = log.link

      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end

  describe "associations" do
    it "belongs to a server" do
      log = create(:log, server: server, user: user)
      expect(log.server).to eq(server)
    end

    it "stores requestors_user_id as discord_id" do
      # Note: The user association uses discord_id as the foreign key value
      # but the association definition expects id lookup, so direct .user
      # access requires the consuming app to configure primary_key
      log = create(:log, server: server, user: user)
      expect(log.requestors_user_id).to eq(user.discord_id)
    end
  end
end
