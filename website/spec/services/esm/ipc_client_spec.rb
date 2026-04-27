# frozen_string_literal: true

require "rails_helper"
require "nats/client"

# Integration spec: requires the docker-compose `nats` service reachable at
# `Settings.nats.url`. Spins up a stub subscriber to receive the signed
# envelope, returns canned responses, and verifies IpcClient's contract.
describe ESM::IpcClient do
  let(:nats_url) { Settings.nats.url }
  let(:subject_prefix) { Settings.nats.subject_prefix }
  let(:secret) { ENV.fetch("API_AUTH_KEY") }
  let(:stub_nats) { NATS.connect(nats_url) }

  before { described_class.reset! }

  after do
    described_class.reset!
    stub_nats.close
  end

  describe ".call" do
    it "builds a signed envelope the bot can verify" do
      captured = nil
      stub_nats.subscribe("#{subject_prefix}ping") do |msg|
        captured = msg.data.parse_json
        msg.respond({ok: true, result: {pong: true}}.to_json)
      end
      stub_nats.flush

      result = described_class.call(:ping, hello: "world")

      expect(result).to be_ok
      expect(result.value).to eq({pong: true})

      expect(captured[:body]).to be_a(String)
      expect(captured[:signature]).to match(/\A[0-9a-f]{64}\z/)

      body = captured[:body].parse_json
      expect(body[:action]).to eq("ping")
      expect(body[:payload]).to eq({hello: "world"})
      expect(body[:nonce]).to match(/\A[0-9a-f-]{36}\z/)

      expected_sig = OpenSSL::HMAC.hexdigest("SHA256", secret, captured[:body])
      expect(captured[:signature]).to eq(expected_sig)
    end

    it "raises RemoteError when the bot responds with ok: false" do
      stub_nats.subscribe("#{subject_prefix}ping") do |msg|
        msg.respond({ok: false, error: "unknown_action", detail: "nope"}.to_json)
      end
      stub_nats.flush

      expect { described_class.call(:ping) }.to raise_error(ESM::IpcClient::RemoteError) do |err|
        expect(err.error_type).to eq(:unknown_action)
        expect(err.message).to eq("nope")
      end
    end

    it "raises Unreachable when the broker is unreachable" do
      client = described_class.new(url: "nats://127.0.0.1:1")

      expect { client.call(:ping) }.to raise_error(ESM::IpcClient::Unreachable)
    end
  end
end
