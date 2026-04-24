# frozen_string_literal: true

require "nats/client"

# Integration spec for the Phase A NATS transport. Assumes a NATS broker is
# reachable at `ENV["NATS_URL"]` (default `nats://127.0.0.1:4222`) — the
# docker-compose `nats` service covers this in dev.
#
# Exercises the globally-booted `ESM::Website::API.server` (registered with
# the `ping` handler in `ESM.run!`) over a real request/reply round-trip.
describe ESM::Website::API::Server do
  let(:nats_url) { ENV.fetch("NATS_URL", "nats://127.0.0.1:4222") }
  let(:secret) { ENV.fetch("API_AUTH_KEY") }
  let(:subject_prefix) { described_class::SUBJECT_PREFIX }
  let(:nats) { NATS.connect(nats_url) }

  after { nats.close }

  def sign(body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body)
  end

  def build_envelope(action:, payload: {})
    body = {
      action: action,
      payload: payload,
      issued_at: Time.now.to_i,
      nonce: SecureRandom.uuid
    }.to_json

    {body: body, signature: sign(body)}.to_json
  end

  def request(action, payload: {}, envelope: nil)
    subject = "#{subject_prefix}#{action}"
    data = envelope || build_envelope(action: action, payload: payload)
    raw = nats.request(subject, data, timeout: 2).data
    JSON.parse(raw, symbolize_names: true)
  end

  describe "round-trip" do
    it "echoes a signed ping request with a server timestamp and nonce" do
      response = request("ping", payload: {hello: "world"})

      expect(response[:ok]).to be(true)
      expect(response[:result][:echo]).to eq({hello: "world"})
      expect(response[:result][:server_time]).to match(/\A\d{4}-\d{2}-\d{2}T/)
      expect(response[:result][:nonce]).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "rejections" do
    it "rejects an envelope with an invalid HMAC signature" do
      body = {action: "ping", payload: {}, issued_at: Time.now.to_i, nonce: "x"}.to_json
      bad = {body: body, signature: "deadbeef" * 8}.to_json

      response = request("ping", envelope: bad)

      expect(response[:ok]).to be(false)
      expect(response[:error]).to eq("signature_invalid")
    end

    it "rejects a signed request for an unregistered action" do
      response = request("definitely_not_a_real_action")

      expect(response[:ok]).to be(false)
      expect(response[:error]).to eq("unknown_action")
    end

    it "rejects a malformed envelope" do
      response = request("ping", envelope: "not-json-at-all")

      expect(response[:ok]).to be(false)
      expect(response[:error]).to eq("invalid_envelope")
    end
  end
end
