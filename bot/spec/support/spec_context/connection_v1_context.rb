# frozen_string_literal: true

RSpec.shared_context("connection_v1") do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:wsc) { WebsocketClient.new(server) }
  let(:connection) { ESM::Websocket.connections[server.server_id] }
  let(:response) { previous_command.response }

  before do
    wait_for { wsc.connected? }.to be(true)
  end

  after do
    wsc.disconnect!
  end
end
