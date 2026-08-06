# frozen_string_literal: true

#
# The A2S client against a real Arma server, which is the only test of it worth trusting.
#
# A recorded reply can only prove the parser still agrees with whoever recorded it. Valve changed this protocol in
# December 2020 by making the challenge round trip mandatory, and every client that had only fixture tests kept
# passing its own suite while failing against every server on the internet. That is exactly how ESM shipped a
# `server details` command that quietly stopped reporting map, players, and version. So this talks to Arma.
#
# Tagged requires_connection because it needs the live server, but deliberately without `include_context "connection"`:
# that context brings up the ESM *extension* link (server key, redis, SQF teardown), and none of it is involved in a
# UDP query. Depending on it would let an unrelated harness problem report itself as a protocol failure.
#
describe ESM::Steam::ServerQuery, requires_connection: true do
  # Published by arma/docker-compose.yml. Arma answers A2S on the game port plus one.
  let(:query_host) { ENV.fetch("ESM_ARMA_QUERY_HOST", "127.0.0.1") }
  let(:query_port) { ENV.fetch("ESM_ARMA_QUERY_PORT", "2303").to_i }

  before do
    described_class.info(host: query_host, port: query_port, timeout: 2)
  rescue described_class::Error => e
    raise "Arma isn't answering A2S on #{query_host}:#{query_port} (#{e.message}). " \
          "Bring it up with `bin/dev` from arma/, which publishes the query port."
  end

  describe ".info" do
    subject(:info) { described_class.info(host: query_host, port: query_port, timeout: 5) }

    it "reads a name the owner would recognize" do
      expect(info.name).to be_a(String)
      expect(info.name).not_to be_empty
      expect(info.name).to be_valid_encoding
    end

    it "names the map the server is running" do
      expect(info.map).to be_a(String)
      expect(info.map).not_to be_empty
    end

    it "identifies itself as Arma 3" do
      expect(info.folder).to eq("Arma3")
    end

    it "names the mod the server is running" do
      expect(info.game).to be_a(String)
      expect(info.game).not_to be_empty
    end

    it "reports a player count that fits inside the server's capacity" do
      expect(info.max_players).to be_positive
      expect(info.players).to be_between(0, info.max_players)
      expect(info.bots).to be >= 0
    end

    it "reports a game version, which is the field a stale client silently drops" do
      expect(info.version).to match(/\A\d+\.\d+/)
    end

    it "reports a protocol number" do
      expect(info.protocol).to be_a(Integer)
    end

    it "answers well inside the timeout a web request can afford" do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      described_class.info(host: query_host, port: query_port, timeout: 5)

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 1
    end

    it "can be asked repeatedly without the second query failing" do
      first = described_class.info(host: query_host, port: query_port, timeout: 5)
      second = described_class.info(host: query_host, port: query_port, timeout: 5)

      expect(second.name).to eq(first.name)
      expect(second.map).to eq(first.map)
    end
  end

  # The reason this client is hand rolled. If Arma ever stops demanding a challenge these fail, and the extra round
  # trip becomes dead weight worth deleting; if a future client author skips the handshake, the first test here shows
  # them precisely what they get back instead of the answer.
  describe "the challenge handshake" do
    def raw_query(challenge: nil)
      socket = UDPSocket.new
      socket.connect(query_host, query_port)
      socket.send(described_class::SIMPLE_HEADER + described_class::A2S_INFO + challenge.to_s, 0)

      raise "server did not answer" unless socket.wait_readable(5)

      socket.recvfrom(4096).first
    ensure
      socket&.close
    end

    it "is still demanded by the server rather than answered outright" do
      reply = raw_query

      expect(reply[4]).to eq("A")
      expect(reply.bytesize).to eq(9)
    end

    it "yields the real answer once the challenge is echoed back" do
      challenge = raw_query.byteslice(5, 4)
      reply = raw_query(challenge:)

      expect(reply[4]).to eq("I")
      expect(described_class.parse_info(reply).folder).to eq("Arma3")
    end

    # A client written before December 2020 stops here, reads the challenge as an answer, and misparses it. This is
    # the shape of the bug that hid map, players, and version for years.
    it "leaves a client that skips it holding a reply that isn't an answer" do
      expect { described_class.parse_info(raw_query) }
        .to raise_error(described_class::UnexpectedResponse, /got "A"/)
    end
  end
end
