# frozen_string_literal: true

# The widest Discord projection the website consumes. Every entry comes from `Discordrb::Channel#to_h`, which is
# ESM's own extension reading discordrb's API, so a rename on either side of that boundary breaks the picker while
# the mocked suite stays green: its channels are built to satisfy the same `to_h` it then asserts on.
RSpec.describe ESM::Website::API::Handlers::CommunityChannels do
  describe ".call" do
    let(:community) do
      ESM::Community.create!(
        community_id: "livechan",
        community_name: "Live Channels",
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

    it "groups the guild's readable channels under their categories, and answers nothing for an unknown guild" do
      grouped = described_class.call(id: community.id, user_id: nil)

      expect(grouped).not_to be_empty

      # The handler always unshifts an uncategorized bucket labelled with the community's own name, so the first
      # entry is the one group that does not come from Discord. Everything after it is a real category.
      uncategorized, *categories = grouped
      expect(uncategorized.first).to eq({name: "Live Channels"})

      expect(grouped).to all(match([Hash, Array]))

      categories.each do |category, children|
        expect(category).to include(:id, :name, :position, :type)
        expect(category[:type]).to be(:category)

        # The grouping is the whole job here: a child listed under a category it does not belong to would render
        # the picker's tree wrong while every individual channel still looked fine.
        children.each do |channel|
          expect(channel[:type]).to be(:text)
          expect(channel.dig(:category, :id)).to eq(category[:id])
        end
      end

      # Ids reach the website as strings and are compared against stored string columns. An Integer here compares
      # unequal against every stored value and silently renders nothing as selected.
      expect(grouped.flat_map(&:last).pluck(:id)).to all(be_a(String))

      expect(described_class.call(id: unknown_community.id, user_id: nil)).to be_nil
    end
  end
end
