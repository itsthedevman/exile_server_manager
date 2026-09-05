# frozen_string_literal: true

RSpec.describe ESM::Server do
  let!(:community) { create(:community) }

  describe ".with_server_id" do
    let!(:server) { create(:server, community: community, server_id: "test_malden") }

    it "matches exact server_id" do
      expect(described_class.with_server_id("test_malden")).to include(server)
    end

    it "is case insensitive" do
      expect(described_class.with_server_id("TEST_MALDEN")).to include(server)
      expect(described_class.with_server_id("Test_Malden")).to include(server)
      expect(described_class.with_server_id("tEsT_mAlDeN")).to include(server)
    end

    it "does not match partial server_id" do
      expect(described_class.with_server_id("test")).not_to include(server)
      expect(described_class.with_server_id("malden")).not_to include(server)
    end
  end

  describe ".by_server_id_fuzzy" do
    let!(:server) { create(:server, community: community, server_id: "esm_tanoa") }

    it "matches partial server_id at the beginning" do
      expect(described_class.by_server_id_fuzzy("esm")).to include(server)
    end

    it "matches partial server_id at the end" do
      expect(described_class.by_server_id_fuzzy("tanoa")).to include(server)
    end

    it "matches partial server_id in the middle" do
      expect(described_class.by_server_id_fuzzy("m_tan")).to include(server)
    end

    it "is case insensitive" do
      expect(described_class.by_server_id_fuzzy("ESM")).to include(server)
      expect(described_class.by_server_id_fuzzy("TANOA")).to include(server)
    end

    it "does not match unrelated strings" do
      expect(described_class.by_server_id_fuzzy("xyz")).not_to include(server)
    end
  end

  describe ".with_local_id" do
    let!(:server_t) { create(:server, community: community, server_id: "esm_t") }
    let!(:server_test) { create(:server, community: community, server_id: "esm_test") }
    let!(:server_testing) { create(:server, community: community, server_id: "esm_testing") }

    it "matches exact local_id" do
      result = described_class.with_local_id("t")
      expect(result).to include(server_t)
      expect(result).not_to include(server_test)
      expect(result).not_to include(server_testing)
    end

    it "does not match partial local_id (the original bug)" do
      # This was the bug: searching for "t" would match "test" because
      # the underscore was being treated as a SQL wildcard
      result = described_class.with_local_id("t")
      expect(result.count).to eq(1)
      expect(result.first).to eq(server_t)
    end

    it "matches longer local_ids exactly" do
      result = described_class.with_local_id("test")
      expect(result).to include(server_test)
      expect(result).not_to include(server_t)
      expect(result).not_to include(server_testing)
    end

    it "is case insensitive" do
      expect(described_class.with_local_id("T")).to include(server_t)
      expect(described_class.with_local_id("TEST")).to include(server_test)
      expect(described_class.with_local_id("TeSt")).to include(server_test)
    end

    it "matches any community prefix with the same local_id" do
      other_community = create(:community)
      other_server = create(:server, community: other_community, server_id: "#{other_community.community_id}_test")

      result = described_class.with_local_id("test")
      expect(result).to include(server_test)
      expect(result).to include(other_server)
    end

    it "escapes SQL wildcards in the local_id input" do
      # Create a server with a local_id containing SQL wildcard characters
      server_with_percent = create(:server, community: community, server_id: "esm_100%done")

      # Searching for "100%" should only match the exact local_id
      result = described_class.with_local_id("100%done")
      expect(result).to include(server_with_percent)

      # Searching for "100" should NOT match "100%done" (% shouldn't act as wildcard)
      result = described_class.with_local_id("100")
      expect(result).not_to include(server_with_percent)
    end

    it "escapes underscore wildcards in the local_id input" do
      # Create servers where underscore matters
      server_a_b = create(:server, community: community, server_id: "esm_a_b")
      server_axb = create(:server, community: community, server_id: "esm_aXb")

      # Searching for "a_b" should match exactly, not treat _ as wildcard
      result = described_class.with_local_id("a_b")
      expect(result).to include(server_a_b)
      expect(result).not_to include(server_axb)
    end
  end

  describe ".find_by_server_id" do
    let!(:server) { create(:server, community: community, server_id: "abc_malden") }

    it "finds server by exact server_id" do
      expect(described_class.find_by_server_id("abc_malden")).to eq(server)
    end

    it "is case insensitive" do
      expect(described_class.find_by_server_id("ABC_MALDEN")).to eq(server)
      expect(described_class.find_by_server_id("Abc_Malden")).to eq(server)
    end

    it "returns nil when not found" do
      expect(described_class.find_by_server_id("nonexistent")).to be_nil
    end

    it "includes community association" do
      result = described_class.find_by_server_id("abc_malden")
      expect(result.association(:community)).to be_loaded
    end
  end

  describe "#local_id" do
    it "extracts the local_id from server_id" do
      server = create(:server, community: community, server_id: "esm_malden")
      expect(server.local_id).to eq("malden")
    end

    it "handles local_ids with underscores" do
      server = create(:server, community: community, server_id: "esm_my_server_name")
      expect(server.local_id).to eq("my_server_name")
    end

    it "handles single character local_ids" do
      server = create(:server, community: community, server_id: "esm_t")
      expect(server.local_id).to eq("t")
    end
  end

  describe "#query_port" do
    it "is the port above the one players join on" do
      server = create(:server, community: community, server_port: "2302")
      expect(server.query_port).to eq(2303)
    end

    # server_port is a string column, so the offset has to survive being read back as text.
    it "returns an integer regardless of how the port was stored" do
      server = create(:server, community: community, server_port: 2302)
      expect(server.query_port).to eq(2303)
    end
  end

  describe "callbacks" do
    describe "before_validation :generate_public_id" do
      it "generates a UUID on create" do
        server = create(:server, community: community)

        expect(server.public_id).to be_present
        expect(server.public_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end

      it "does not overwrite existing public_id" do
        existing_id = SecureRandom.uuid
        server = create(:server, community: community, public_id: existing_id)

        expect(server.public_id).to eq(existing_id)
      end
    end

    describe "before_validation :generate_key" do
      it "generates a 64-character server_key on create" do
        server = create(:server, community: community)

        expect(server.server_key).to be_present
        expect(server.server_key.length).to eq(64)
      end

      it "does not overwrite existing server_key" do
        existing_key = "x" * 64
        server = create(:server, community: community, server_key: existing_key)

        expect(server.server_key).to eq(existing_key)
      end
    end

    describe "after_create :create_server_setting" do
      it "creates a server_setting automatically" do
        server = create(:server, :with_callbacks, community: community)

        expect(server.server_setting).to be_present
        expect(server.server_setting).to be_a(ESM::ServerSetting)
      end
    end

    describe "after_create :create_default_reward" do
      it "creates a default reward automatically" do
        server = create(:server, :with_callbacks, community: community)

        expect(server.server_rewards.default.first).to be_present
      end
    end
  end

  describe "#token" do
    let(:server) { create(:server, community: community) }

    it "returns a hash with access and secret" do
      token = server.token

      expect(token).to be_a(Hash)
      expect(token[:access]).to eq(server.public_id)
      expect(token[:secret]).to eq(server.server_key)
    end

    it "memoizes the result" do
      first_call = server.token
      second_call = server.token

      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end

  describe "#version" do
    let(:server) { create(:server, community: community) }

    it "returns a Semantic::Version object" do
      server.update_column(:server_version, "2.1.0")
      expect(server.version).to be_a(Semantic::Version)
    end

    it "defaults to 1.0.0 when server_version is nil" do
      server.update_column(:server_version, nil)
      expect(server.version.to_s).to eq("1.0.0")
    end
  end

  describe "#version?" do
    let(:server) { create(:server, community: community) }

    it "returns true when version meets requirement" do
      server.update_column(:server_version, "2.1.0")

      expect(server.version?("2.0.0")).to be(true)
      expect(server.version?("2.1.0")).to be(true)
      expect(server.version?("1.0.0")).to be(true)
    end

    it "returns false when version does not meet requirement" do
      server.update_column(:server_version, "1.5.0")

      expect(server.version?("2.0.0")).to be(false)
    end
  end

  describe "#v2?" do
    let(:server) { create(:server, community: community) }

    it "returns true for v2+ servers" do
      server.update_column(:server_version, "2.0.0")
      expect(server.v2?).to be(true)

      server.update_column(:server_version, "2.5.0")
      expect(server.v2?).to be(true)
    end

    it "returns false for v1 servers" do
      server.update_column(:server_version, "1.9.9")
      expect(server.v2?).to be(false)
    end
  end

  describe "#uptime" do
    let(:server) { create(:server, community: community) }

    it "returns 'Offline' when server_start_time is nil" do
      server.update_column(:server_start_time, nil)
      expect(server.uptime).to eq("Offline")
    end

    it "returns time since server started" do
      server.update_column(:server_start_time, 2.hours.ago)
      expect(server.uptime).to match(/hour/i)
    end
  end

  describe "#time_left_before_restart" do
    let(:server) { create(:server, :with_setting, community: community) }

    it "returns 'Offline' when server_start_time is nil" do
      server.update_column(:server_start_time, nil)
      expect(server.time_left_before_restart).to eq("Offline")
    end

    it "calculates time until restart" do
      server.update_column(:server_start_time, Time.current)
      server.server_setting.update!(server_restart_hour: 4, server_restart_min: 0)

      result = server.time_left_before_restart
      expect(result).to match(/hour/i)
    end
  end

  describe "#time_since_last_connection" do
    let(:server) { create(:server, community: community) }

    it "returns time since disconnected_at" do
      server.update_column(:disconnected_at, 1.hour.ago)
      expect(server.time_since_last_connection).to match(/hour/i)
    end
  end

  describe "validations" do
    it "requires public_id to be unique" do
      server1 = create(:server, community: community)
      server2 = build(:server, community: community, public_id: server1.public_id)

      expect(server2).not_to be_valid
      expect(server2.errors[:public_id]).to include("has already been taken")
    end
  end
end
