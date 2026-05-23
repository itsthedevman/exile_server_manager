# frozen_string_literal: true

# Smoke verifies that ESM::Website::API::Server.start wires every handler
# registered in .register_handlers to a live NATS subject. Each action gets
# poked with a payload that early-returns nil so we don't need DB or Discord
# fixtures - the value here is catching a missing register call, a renamed
# subject, or an envelope-serialization regression.
#
RSpec.describe ESM::Website::API::Server, "full handler wiring", :integration do
  let(:secret) { SecureRandom.hex(32) }
  let(:subject_prefix) { "esm.bot.rpc." }
  let(:broker) { Spec::NatsBroker.new.start }
  let(:client) { NATS.connect(broker.url) }

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
    described_class.start
  end

  after do
    described_class.stop
    client.close
    broker.stop
    Settings.nats.url = original_url
    Settings.nats.shared_secret = original_secret
  end

  # Every action listed here has a registered handler whose nil-record path
  # we can reach with throwaway IDs. Adding a new RPC means adding a row here.
  actions = {
    ping: {},
    requests_accept: {id: -1},
    requests_decline: {id: -1},
    servers_update: {id: -1},
    servers_reconnect: {id: -1, old_id: "missing"},
    servers_connected: {id: -1},
    channel: {id: -1},
    channel_send: {id: -1, message: "x"},
    community_channels: {id: -1, user_id: -1},
    community_modifiable_by: {id: -1, user_id: -1},
    community_roles: {id: -1},
    community_users: {id: -1},
    community_delete: {id: -1, user_id: -1},
    user_communities: {id: -1, guild_ids: []},
    user_community_permissions: {id: -1, guild_ids: []}
  }

  actions.each do |action, payload|
    it "responds with ok envelope for #{action}" do
      envelope = build_envelope.call(action: action.to_s, payload: payload)
      response = client.request("#{subject_prefix}#{action}", envelope.to_json, timeout: 5)
      parsed = JSON.parse(response.data, symbolize_names: true)

      expect(parsed[:ok]).to be(true), "expected ok=true for #{action}, got #{parsed.inspect}"
    end
  end

  it "leaves unregistered subjects without responders" do
    expect {
      client.request(
        "#{subject_prefix}not_a_real_action",
        build_envelope.call(action: "not_a_real_action", payload: {}).to_json,
        timeout: 1
      )
    }.to raise_error(NATS::IO::NoRespondersError)
  end
end
