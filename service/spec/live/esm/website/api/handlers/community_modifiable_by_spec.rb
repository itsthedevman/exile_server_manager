# frozen_string_literal: true

# The live counterpart to spec/esm/website/api/handlers/community_modifiable_by_spec.rb. This is the permission gate
# the website's dashboard depends on, and it resolves guild membership through Discord, so a mocked version of it
# only ever proves that the fake member answered the way the fake was built to answer.
RSpec.describe ESM::Website::API::Handlers::CommunityModifiableBy do
  describe ".call" do
    let(:community) do
      ESM::Community.create!(
        community_id: "livemod",
        community_name: "Live Modifiable",
        guild_id: Spec::TestData.guild_id
      )
    end

    let(:owner) do
      ESM::User.create!(discord_id: Spec::TestData.owner_discord_id, discord_username: "guild owner")
    end

    let(:role_holder) do
      ESM::User.create!(discord_id: Spec::TestData.role_user.fetch(:id).to_s, discord_username: "role holder")
    end

    let(:role_id) { Spec::TestData.role_user.fetch(:role_id).to_s }

    # The second and third assertions are the same user against the same guild, so the only thing that can move the
    # answer is the community's own configuration. That is the behavior the dashboard gate rests on, and it is the
    # half a fake cannot check: the membership lookup in between is real.
    it "grants the guild owner outright, and a member only once their role is configured" do
      expect(described_class.call(id: community.id, user_id: owner.id)).to be(true)

      expect(community.dashboard_access_role_ids).to be_empty
      expect(described_class.call(id: community.id, user_id: role_holder.id)).to be(false)

      community.update!(dashboard_access_role_ids: [role_id])

      expect(described_class.call(id: community.id, user_id: role_holder.id)).to be(true)
    end
  end
end
