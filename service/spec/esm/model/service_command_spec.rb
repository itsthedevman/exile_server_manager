# frozen_string_literal: true

RSpec.describe ESM::ServiceCommand do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let!(:user) { create(:user) }

  subject(:service_command) do
    described_class.create!(
      user:,
      server:,
      community:,
      idempotency_key: SecureRandom.uuid,
      command_name: "gamble",
      status: :pending
    )
  end

  describe "#settled?" do
    it "is false while the row is still in flight" do
      expect(service_command.settled?).to be(false)

      service_command.dispatched!
      expect(service_command.settled?).to be(false)
    end

    it "is true once the row reaches a terminal status" do
      %i[completed! failed! timed_out!].each do |terminal|
        service_command.public_send(terminal)

        expect(service_command.settled?).to be(true)
      end
    end
  end

  describe "#command_class" do
    it "resolves the command class from the stored command_name" do
      expect(service_command.command_class).to eq(ESM::Command::Server::Gamble)
    end
  end

  describe "#community" do
    it "is read off the row" do
      expect(service_command.community).to eq(community)
    end

    it "is still known when the command has no server to run against" do
      command = described_class.create!(
        user:,
        community:,
        idempotency_key: SecureRandom.uuid,
        command_name: "gamble",
        status: :pending
      )

      expect(command.server).to be_nil
      expect(command.community).to eq(community)
    end
  end
end
