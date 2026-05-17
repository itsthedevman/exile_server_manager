# frozen_string_literal: true

# V1 (websocket) connection context. Layered on top of the "command" shared
# context — it inherits community / server / discord_server / user from there
# and only adds the WebsocketClient that simulates the Arma side.
RSpec.shared_context("connection_v1") do
  let!(:wsc) { WebsocketClient.new(server) }
  let(:connection) { ESM::Websocket.connections[server.server_id] }
  let(:response) { previous_command.response }

  before do
    wait_for { wsc.connected? }.to be(true)
  end

  after do
    wsc.disconnect!
    ESM::Websocket.remove_all_connections!
  end
end
