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
end
