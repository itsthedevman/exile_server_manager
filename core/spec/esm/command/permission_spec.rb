# frozen_string_literal: true

RSpec.describe ESM::Command::Permission do
  # A real command carries the declarations the resolver reads: Gamble is a registration-gated player command whose
  # command_name is "gamble" and whose attributes default to enabled, no allowlist, and a 2 second cooldown.
  let(:command) { ESM::Command::Server::Gamble }
  let(:user) { create(:user) }
  let(:community) { create(:community) }
  let(:cooldown) { nil }

  subject(:permission) do
    described_class.new(command:, user:, community:, cooldown:)
  end

  # Overrides the community's configuration for the command under test. Absent one, the resolver falls back to the
  # command's declared defaults.
  def configure(**attributes)
    create(:command_configuration, community:, command_name: "gamble", **attributes)
  end

  describe "#resolve" do
    context "when the user clears every gate" do
      it "is allowed" do
        result = permission.resolve

        expect(result).to be_allowed
        expect(result.reason).to be_nil
      end
    end

    context "when the command requires registration and the user is unregistered" do
      let(:user) { create(:user, :unregistered) }

      it "is denied with :unregistered" do
        expect(permission.resolve.reason).to eq(:unregistered)
      end
    end

    context "when the community has disabled the command" do
      before { configure(enabled: false) }

      it "is denied with :disabled" do
        expect(permission.resolve.reason).to eq(:disabled)
      end
    end

    context "when an allowlist is enabled" do
      before { configure(allowlist_enabled: true, allowlisted_role_ids: ["100", "200"]) }

      it "denies a user holding none of the allowlisted roles" do
        expect(permission.resolve(role_ids: [300, 400]).reason).to eq(:not_allowlisted)
      end

      it "allows a user holding an allowlisted role" do
        expect(permission.resolve(role_ids: [200, 300])).to be_allowed
      end

      it "allows an administrator regardless of roles" do
        expect(permission.resolve(role_ids: [], administrator: true)).to be_allowed
      end
    end

    context "when the target server is offline" do
      it "is denied with :server_offline" do
        expect(permission.resolve(server_online: false).reason).to eq(:server_offline)
      end
    end

    context "when the user is on cooldown" do
      let(:cooldown) do
        create(:cooldown, user:, community:, command_name: "gamble", cooldown_type: "seconds",
          cooldown_quantity: 60, expires_at: 60.seconds.from_now)
      end

      it "is denied with :on_cooldown and carries the time left" do
        result = permission.resolve

        expect(result.reason).to eq(:on_cooldown)
        expect(result.detail[:time_left]).to be_present
      end
    end

    context "when more than one gate fails" do
      let(:user) { create(:user, :unregistered) }

      before { configure(enabled: false) }

      it "reports the most fundamental one first" do
        expect(permission.resolve.reason).to eq(:unregistered)
      end
    end
  end

  describe "configuration resolution" do
    context "without a community override" do
      it "reads the command's declared defaults" do
        expect(permission.enabled?).to be(true)
        expect(permission.allowlist_enabled?).to be(false)
        expect(permission.allowlisted_role_ids).to eq([])
        expect(permission.cooldown_time).to eq(2.seconds)
      end
    end

    context "with a community override" do
      before do
        configure(enabled: false, allowlist_enabled: true, allowlisted_role_ids: ["9"],
          cooldown_quantity: 5, cooldown_type: "minutes")
      end

      it "reads the override row" do
        expect(permission.enabled?).to be(false)
        expect(permission.allowlist_enabled?).to be(true)
        expect(permission.allowlisted_role_ids).to eq(["9"])
        expect(permission.cooldown_time).to eq(5.minutes)
      end
    end
  end
end
