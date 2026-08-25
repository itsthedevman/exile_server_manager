# frozen_string_literal: true

require "nats/client"
require_relative Rails.root.join("spec/support/spec/nats_broker")

# Boots an isolated nats-server, hand-rolls a subscriber that mimics what the
# bot would do, and verifies ESM::Service::API's full surface: signed envelopes,
# the handler result on success, RemoteError on ok=false, Unreachable on transport failure.
#
RSpec.describe ESM::Service::API do
  let(:secret) { SecureRandom.hex(32) }
  let(:subject_prefix) { Settings.nats.subject_prefix }
  let(:broker) { Spec::NatsBroker.new.start }
  let(:stub_nats) { NATS.connect(broker.url) }

  let!(:original_url) { Settings.nats.url }
  let!(:original_secret) { Settings.nats.shared_secret }

  before do
    Settings.nats.url = broker.url
    Settings.nats.shared_secret = secret
    described_class.reset!
  end

  after do
    described_class.reset!
    stub_nats.close
    broker.stop
    Settings.nats.url = original_url
    Settings.nats.shared_secret = original_secret
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

      expect(result).to eq({pong: true})

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

      expect { described_class.call(:ping) }.to raise_error(ESM::Service::API::RemoteError) do |err|
        expect(err.error_type).to eq(:unknown_action)
        expect(err.message).to eq("nope")
      end
    end

    it "raises Unreachable when the broker is unreachable" do
      client = described_class.new(url: "nats://127.0.0.1:1")

      expect { client.call(:ping) }.to raise_error(ESM::Service::API::Unreachable)
    end

    it "raises Unreachable when the broker is up but no subscriber answers" do
      expect { described_class.call(:not_a_real_action) }.to raise_error(ESM::Service::API::Unreachable)
    end

    # The client is told not to reconnect, which is what keeps a down bot from blocking a request for the better part
    # of a minute. This is the other half of that bargain: a client parked at DISCONNECTED still dials again on its
    # next request, so the shared connection survives a bot restart without anyone reaching for reset!.
    it "recovers on its own after the broker restarts" do
      responder = proc { |msg| msg.respond({ok: true, result: {pong: true}}.to_json) }

      stub_nats.subscribe("#{subject_prefix}ping", &responder)
      stub_nats.flush

      expect(described_class.call(:ping)).to eq({pong: true})

      broker.restart

      resubscribed = NATS.connect(broker.url)
      resubscribed.subscribe("#{subject_prefix}ping", &responder)
      resubscribed.flush

      expect(described_class.call(:ping, idempotent: true)).to eq({pong: true})
    ensure
      resubscribed&.close
    end
  end
end
