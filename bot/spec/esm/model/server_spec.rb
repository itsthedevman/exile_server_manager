# frozen_string_literal: true

describe ESM::Server do
  let!(:server) { ESM::Test.server }

  describe "find_by_server_id" do
    it "is case insensitive" do
      server.update!(server_id: "teST")

      expect(described_class.find_by_server_id("test")).to eq(server)
      expect(described_class.find_by_server_id("teST")).to eq(server)
      expect(described_class.find_by_server_id("tEsT")).to eq(server)
    end
  end
end
