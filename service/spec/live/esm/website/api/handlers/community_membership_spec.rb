# frozen_string_literal: true

# Feeds the command allowlist pickers: which of the guild's roles a user actually holds, and whether they are an
# administrator. Both halves come from a live membership lookup, so a mocked version can only confirm that the
# hand-built member reported the roles it was hand-built with.
RSpec.describe ESM::Website::API::Handlers::CommunityMembership do
  describe ".call" do
    let(:community) do
      ESM::Community.create!(
        community_id: "livemem",
        community_name: "Live Membership",
        guild_id: Spec::TestData.guild_id
      )
    end

    let(:role_holder) do
      ESM::User.create!(discord_id: Spec::TestData.role_user.fetch(:id).to_s, discord_username: "role holder")
    end

    let(:owner) do
      ESM::User.create!(discord_id: Spec::TestData.owner_discord_id, discord_username: "guild owner")
    end

    let(:role_id) { Spec::TestData.role_user.fetch(:role_id).to_s }

    it "reports the roles a member holds without @everyone, and their administrator standing" do
      membership = described_class.call(user_id: role_holder.id, community_id: community.id)

      expect(membership).to include(:role_ids, :administrator)

      # The role this member is known to hold. Asserting on presence rather than on the whole list, because roles
      # can be added in that guild without this spec being wrong.
      expect(membership[:role_ids]).to include(role_id)
      expect(membership[:role_ids]).to all(be_a(String))

      # Every member holds @everyone and the picker never lists it, so it is dropped. It would otherwise show up in
      # every allowlist as a role that grants nothing.
      expect(membership[:role_ids]).not_to include(Spec::TestData.everyone_role_id)

      # The two identities have to disagree here, or the flag is not being read from the member at all.
      expect(membership[:administrator]).to be(false)
      expect(described_class.call(user_id: owner.id, community_id: community.id)[:administrator]).to be(true)
    end
  end
end
