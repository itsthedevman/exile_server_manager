# frozen_string_literal: true

describe ESM::Server do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server(for: community) }

  # rubocop:disable Rails/DynamicFindBy
  describe "find_by_server_id" do
    it "is case insensitive" do
      server.update!(server_id: "teST")

      expect(described_class.find_by_server_id("test")).to eq(server)
      expect(described_class.find_by_server_id("teST")).to eq(server)
      expect(described_class.find_by_server_id("tEsT")).to eq(server)
    end
  end
  # rubocop:enable Rails/DynamicFindBy

  describe "#correct" do
    subject(:server_id) { server.server_id }

    context "when the server ID is correct" do
      it "provides no corrections" do
        corrections = ESM::Server.correct_id(server_id)

        expect(corrections).to be_blank
      end
    end

    context "when the server ID is incorrect" do
      let!(:server_id_partial) { server_id[0..Faker::Number.between(from: server_id.size / 2, to: server_id.size)] }

      it "provides a correction" do
        correction = ESM::Server.correct_id(server_id_partial)

        expect(correction).not_to be_blank, "Checking #{server_id_partial} in #{described_class.server_ids}"
        expect(correction.first).to eq(server.server_id)
      end
    end
  end
end
