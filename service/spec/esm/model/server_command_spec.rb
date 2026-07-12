# frozen_string_literal: true

RSpec.describe ESM::ServerCommand do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let!(:user) { create(:user) }

  subject(:server_command) do
    described_class.create!(
      user:,
      server:,
      idempotency_key: SecureRandom.uuid,
      command_name: "gamble",
      status: :pending
    )
  end

  describe "#settled?" do
    it "is false while the row is still in flight" do
      expect(server_command.settled?).to be(false)

      server_command.dispatched!
      expect(server_command.settled?).to be(false)
    end

    it "is true once the row reaches a terminal status" do
      %i[completed! failed! timed_out!].each do |terminal|
        server_command.public_send(terminal)

        expect(server_command.settled?).to be(true)
      end
    end
  end

  describe "#command_class" do
    it "resolves the command class from the stored command_name" do
      expect(server_command.command_class).to eq(ESM::Command::Server::Gamble)
    end
  end

  describe "#community" do
    it "is reachable through the server" do
      expect(server_command.community).to eq(community)
    end
  end
end
