# frozen_string_literal: true

RSpec.describe ESM::Website::API::Server, :integration do
  let(:secret) { SecureRandom.hex(32) }
  let(:subject_prefix) { "esm.bot.rpc." }
  let(:broker) { Spec::NatsBroker.new.start }
  let(:client) { NATS.connect(broker.url) }
  let(:handler) { ESM::Website::API::Handlers::Ping }
  let(:server) { described_class.new.register(:ping, handler) }

  let(:build_envelope) do
    ->(action:, payload:) {
      body = {action:, payload:, issued_at: Time.now.to_i, nonce: SecureRandom.uuid}.to_json
      {body:, signature: OpenSSL::HMAC.hexdigest("SHA256", secret, body)}
    }
  end

  let!(:original_url) { Settings.nats.url }
  let!(:original_secret) { Settings.nats.shared_secret }

  before do
    Settings.nats.url = broker.url
    Settings.nats.shared_secret = secret
    server.start
  end

  after do
    server.stop
    client.close
    broker.stop
    Settings.nats.url = original_url
    Settings.nats.shared_secret = original_secret
  end

  describe "round-trip" do
    it "returns the handler result inside an ok envelope" do
      envelope = build_envelope.call(action: "ping", payload: {hello: "world"})

      response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 5)
      parsed = JSON.parse(response.data, symbolize_names: true)

      expect(parsed[:ok]).to be true
      expect(parsed.dig(:result, :echo, :hello)).to eq("world")
      expect(parsed.dig(:result, :server_time)).to be_a(String)
    end
  end

  describe "deferred handler" do
    context "when the handler offloads to a promise that resolves" do
      let(:handler) do
        Class.new do
          def self.call(**payload)
            Concurrent::Promise.execute { {deferred: payload[:value]} }
          end
        end
      end

      it "replies with the resolved value once the promise settles" do
        envelope = build_envelope.call(action: "ping", payload: {value: 42})

        response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 5)
        parsed = JSON.parse(response.data, symbolize_names: true)

        expect(parsed[:ok]).to be true
        expect(parsed.dig(:result, :deferred)).to eq(42)
      end
    end

    context "when the handler's promise rejects" do
      let(:handler) do
        Class.new do
          def self.call(**)
            Concurrent::Promise.execute { raise StandardError, "secret background detail" }
          end
        end
      end

      it "replies with a redacted error once the promise rejects" do
        envelope = build_envelope.call(action: "ping", payload: {})

        response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 5)
        parsed = JSON.parse(response.data, symbolize_names: true)

        expect(parsed[:ok]).to be false
        expect(parsed[:error]).to eq("unknown")
        expect(parsed[:detail]).not_to include("secret background detail")
      end
    end
  end

  describe "envelope shape" do
    it "rejects a body that's valid JSON but not a Hash" do
      body = "null"
      envelope = {
        body: body,
        signature: OpenSSL::HMAC.hexdigest("SHA256", secret, body)
      }

      response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 5)
      parsed = JSON.parse(response.data, symbolize_names: true)

      expect(parsed[:ok]).to be false
      expect(parsed[:error]).to eq("invalid_envelope")
    end

    it "rejects an envelope whose issued_at is older than the staleness window" do
      stale_body = {
        action: "ping",
        payload: {},
        issued_at: Time.now.to_i - (10 * 60),
        nonce: SecureRandom.uuid
      }.to_json
      envelope = {
        body: stale_body,
        signature: OpenSSL::HMAC.hexdigest("SHA256", secret, stale_body)
      }

      response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 5)
      parsed = JSON.parse(response.data, symbolize_names: true)

      expect(parsed[:ok]).to be false
      expect(parsed[:error]).to eq("invalid_envelope")
    end
  end

  describe "internal error redaction" do
    let(:handler) { class_double(ESM::Website::API::Handlers::Ping) }

    before { allow(handler).to receive(:call).and_raise(StandardError, "secret internal detail with table=communities sql=...") }

    it "returns a generic detail string for :unknown errors, not the exception message" do
      envelope = build_envelope.call(action: "ping", payload: {})
      response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 5)
      parsed = JSON.parse(response.data, symbolize_names: true)

      expect(parsed[:ok]).to be false
      expect(parsed[:error]).to eq("unknown")
      expect(parsed[:detail]).not_to include("secret internal detail")
      expect(parsed[:detail]).not_to include("communities")
    end
  end

  describe "HMAC verification" do
    let(:handler) { class_double(ESM::Website::API::Handlers::Ping, call: {echo: {}}) }

    it "rejects an envelope with a bad signature without invoking the handler" do
      envelope = build_envelope.call(action: "ping", payload: {hello: "world"})
      tampered = envelope.merge(signature: "deadbeef" * 8)

      response = client.request("#{subject_prefix}ping", tampered.to_json, timeout: 5)
      parsed = JSON.parse(response.data, symbolize_names: true)

      expect(parsed[:ok]).to be false
      expect(parsed[:error]).to eq("signature_invalid")
      expect(handler).not_to have_received(:call)
    end
  end

  describe "broker reconnect" do
    let(:client) { NATS.connect(broker.url, reconnect_time_wait: 0.1, max_reconnect_attempts: 50) }

    it "re-establishes the subscription after the broker restarts" do
      first = client.request(
        "#{subject_prefix}ping",
        build_envelope.call(action: "ping", payload: {phase: "before"}).to_json,
        timeout: 5
      )
      expect(JSON.parse(first.data, symbolize_names: true)[:ok]).to be true

      broker.restart

      # The server's @nats client uses default reconnect_time_wait (2s), so poll
      # for a successful response rather than guessing the right sleep.
      parsed = nil
      deadline = Time.now + 10
      loop do
        envelope = build_envelope.call(action: "ping", payload: {phase: "after"})
        response = client.request("#{subject_prefix}ping", envelope.to_json, timeout: 2)
        parsed = JSON.parse(response.data, symbolize_names: true)
        break if parsed[:ok]
        raise "broker reconnect did not re-establish subscription within 10s" if Time.now > deadline
      rescue NATS::IO::NoRespondersError, NATS::IO::Timeout
        raise if Time.now > deadline
        sleep 0.2
        retry
      end

      expect(parsed[:ok]).to be true
      expect(parsed.dig(:result, :echo, :phase)).to eq("after")
    end
  end
end
