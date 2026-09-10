# frozen_string_literal: true

# The live counterpart to spec/esm/website/api/handlers/community_roles_spec.rb. That one builds a Discordrb::Server
# by hand and pushes it into the bot's cache, so it proves the filtering and the shape but never touches a gateway.
# This one asks Discord.
#
# Assertions are on shape rather than content. The roles in that guild are renamed from Discord's own UI, and a spec
# pinned to their names would fail on an edit that broke nothing.
RSpec.describe ESM::Website::API::Handlers::CommunityRoles do
  describe ".call" do
    let(:community) do
      ESM::Community.create!(
        community_id: "livedisc",
        community_name: "Live Discord",
        guild_id: Spec::TestData.guild_id
      )
    end

    # Same call, same committed row, and the only difference is whether the guild id resolves in the bot's cache.
    # Without this, every assertion above would pass just as well against a bot that had never connected.
    let(:unknown_community) do
      ESM::Community.create!(
        community_id: "livenone",
        community_name: "Live No Guild",
        guild_id: Spec::TestData.unknown_guild_id
      )
    end

    it "returns the guild's selectable roles, and nothing at all for a guild the bot is not in" do
      roles = described_class.call(id: community.id)

      # Guards the shape checks below rather than asserting content: every one of them passes trivially against an
      # empty list, which is also what an unreadable guild looks like from one layer up.
      expect(roles).not_to be_empty

      expect(roles).to all(include(:id, :name, :color, :disabled))
      expect(roles.pluck(:name)).not_to include("@everyone")

      # The website matches these against territory_admin_ids and dashboard_access_role_ids, both stored as strings.
      # An id arriving as an Integer compares unequal against every stored value and quietly renders nothing as
      # already selected, with no error anywhere.
      expect(roles.pluck(:id)).to all(be_a(String))

      expect(described_class.call(id: unknown_community.id)).to be_nil
    end
  end
end
