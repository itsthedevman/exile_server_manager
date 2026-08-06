# frozen_string_literal: true

#
# The happy path lives in service/spec/esm/steam/server_query_spec.rb, against a real Arma server. A fixture of a
# reply can only ever prove the parser still agrees with whoever wrote the fixture, which is no help at all when
# Valve changes the protocol - that is precisely how a client can keep passing its own suite while failing against
# every server on the internet.
#
# What is left here is the failure handling: replies a working server never sends, so a live test has no way to
# provoke them.
#
RSpec.describe ESM::Steam::ServerQuery do
  describe ".parse_info" do
    it "rejects a challenge reply rather than reading it as an answer" do
      challenge = described_class::SIMPLE_HEADER + "A".b + "\x01\x02\x03\x04".b

      expect { described_class.parse_info(challenge) }
        .to raise_error(described_class::UnexpectedResponse, /got "A"/)
    end

    it "names a split reply as split instead of failing to parse it" do
      reply = described_class::SPLIT_HEADER + "I".b + "\x11".b

      expect { described_class.parse_info(reply) }
        .to raise_error(described_class::UnexpectedResponse, /split/)
    end

    it "rejects a datagram that isn't a Valve reply at all" do
      expect { described_class.parse_info("http response, wrong port entirely".b) }
        .to raise_error(described_class::UnexpectedResponse, /not a Valve query reply/)
    end

    it "rejects an empty datagram" do
      expect { described_class.parse_info("".b) }
        .to raise_error(described_class::UnexpectedResponse, /not a Valve query reply/)
    end

    it "rejects a reply that ends partway through a string" do
      truncated = described_class::SIMPLE_HEADER + "I".b + "\x11".b + "exilemo".b

      expect { described_class.parse_info(truncated) }
        .to raise_error(described_class::UnexpectedResponse, /ended mid string/)
    end

    it "rejects a reply that ends partway through a number" do
      # Four complete names and then nothing, so the app id has nowhere to come from.
      truncated = described_class::SIMPLE_HEADER + "I".b + "\x11".b + "a\x00b\x00c\x00d\x00".b

      expect { described_class.parse_info(truncated) }
        .to raise_error(described_class::UnexpectedResponse, /ended after/)
    end
  end

  describe ".info" do
    # A port with nothing behind it is the ordinary case for an offline server. It must surface as this class's own
    # error rather than leaking an errno, so one rescue covers every way a server can be unreachable.
    it "raises its own error when nothing is listening" do
      expect { described_class.info(host: "127.0.0.1", port: 1, timeout: 0.5) }
        .to raise_error(described_class::Error)
    end

    # 198.51.100.0/24 is reserved for documentation, so nothing routes there and the wait is the whole story. A web
    # request must not hang on a server that has gone dark.
    it "times out rather than blocking forever when the datagram goes nowhere" do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { described_class.info(host: "198.51.100.1", port: 2303, timeout: 0.5) }
        .to raise_error(described_class::Timeout, /did not answer/)

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 2
    end
  end
end
