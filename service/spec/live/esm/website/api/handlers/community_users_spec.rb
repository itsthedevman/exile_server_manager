# frozen_string_literal: true

# The third of ESM's `to_h` projections over discordrb, after channel and member.
#
# It is `Member#to_h` that answers here, not `User#to_h`, because `Discordrb::Server#users` returns members. ESM
# defines both, and the member one carries only id and username where the user one adds avatar, status and creation
# time. Worth stating because the handler's name points the other way, and the mocked spec asserts nothing beyond
# `all(be_a(Hash))`, so it would pass just as happily against either.
RSpec.describe ESM::Website::API::Handlers::CommunityUsers do
  describe ".call" do
    let(:community) do
      ESM::Community.create!(
        community_id: "liveuser",
        community_name: "Live Users",
        guild_id: Spec::TestData.guild_id
      )
    end

    let(:unknown_community) do
      ESM::Community.create!(
        community_id: "livenone",
        community_name: "Live No Guild",
        guild_id: Spec::TestData.unknown_guild_id
      )
    end

    it "projects every member of the guild, and answers nothing for a guild the bot is not in" do
      users = described_class.call(id: community.id)

      expect(users).not_to be_empty

      # contain_exactly rather than include, so a field silently appearing or vanishing under the projection is a
      # failure here rather than a surprise at the consumer.
      expect(users.map(&:keys)).to all(contain_exactly(:id, :username))
      expect(users.pluck(:id)).to all(be_a(String))

      # The guild owner is a member by definition, so their absence means the list is not the guild's membership.
      expect(users.pluck(:id)).to include(Spec::TestData.owner_discord_id)

      expect(described_class.call(id: unknown_community.id)).to be_nil
    end
  end
end
