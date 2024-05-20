# frozen_string_literal: true

describe ESM::Connection::ConnectionManager, v2: true do
  describe "#check_lobby" do
    let(:tpc_socket) do
      Class.new(TCPSocket) do
        def initialize
        end

        def local_address
          OpenStruct.new
        end
      end.new
    end

    context "when the client has not been in the waiting room long enough to time out" do
      subject(:connection_manager) { described_class.new(2) }

      it "does not time out the client" do
        lobby = connection_manager.instance_variable_get(:@lobby)

        expect(lobby.size).to eq(0)

        connection_manager.on_connect(tpc_socket)

        expect(lobby.size).to eq(1)
      end
    end

    context "when the client has been in the waiting room for too long" do
      subject(:connection_manager) { described_class.new(0.01, execution_interval: 0.5) }

      it "times out the client" do
        lobby = connection_manager.instance_variable_get(:@lobby)
        expect(lobby.size).to eq(0)

        connection_manager.on_connect(tpc_socket)

        sleep(1)
        info!("BEFORE CHECK")
        expect(lobby.size).to eq(0)
      end
    end
  end
end
