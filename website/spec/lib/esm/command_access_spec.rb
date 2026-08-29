# frozen_string_literal: true

RSpec.describe ESM::CommandAccess do
  let(:user) { create(:user) }
  let(:community) { create(:community) }
  let(:administrator) { true }

  # The website can't read Discord role membership, so every verdict sources it from the bot. Holding administrator
  # clears broadcast's allowlist, which leaves connectivity as the only gate these examples vary.
  let(:membership) { {role_ids: [], administrator:}.to_struct }

  before { allow(community).to receive(:membership_for).with(user).and_return(membership) }

  describe "#initialize" do
    it "refuses to gate a command given neither a community nor a server" do
      expect { described_class.new(command_name: "broadcast", user:) }
        .to raise_error(ArgumentError, /needs a community or a server/)
    end

    it "refuses to gate a command given a server that names no community" do
      server = create(:server, community:)
      allow(server).to receive(:community).and_return(nil)

      expect { described_class.new(command_name: "broadcast", user:, server:) }
        .to raise_error(ArgumentError, /needs a community or a server/)
    end
  end

  describe "#verdict" do
    context "when the command targets a server" do
      let(:server) { create(:server, community:) }

      before { allow(server).to receive(:connected?).and_return(connected) }

      context "and that server is connected" do
        let(:connected) { true }

        it "allows the command" do
          expect(described_class.new(command_name: "broadcast", user:, server:).verdict).to be_allowed
        end
      end

      context "and that server is offline" do
        let(:connected) { false }

        it "denies the command" do
          result = described_class.new(command_name: "broadcast", user:, server:).verdict

          expect(result).to be_denied
          expect(result.reason).to eq(:server_offline)
        end
      end
    end

    context "when the command is scoped to a community" do
      it "allows the command, having no server that could be offline" do
        expect(described_class.new(command_name: "broadcast", user:, community:).verdict).to be_allowed
      end

      context "and the user holds none of the allowlisted roles" do
        let(:administrator) { false }

        it "denies the command" do
          result = described_class.new(command_name: "broadcast", user:, community:).verdict

          expect(result).to be_denied
          expect(result.reason).to eq(:not_allowlisted)
        end
      end
    end
  end
end
