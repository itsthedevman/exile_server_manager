# frozen_string_literal: true

RSpec.describe Discordrb::User do
  subject(:discord_user) { build(:discord_user) }

  describe "#to_h" do
    it "projects the identity fields the website reads" do
      expect(discord_user.to_h.keys).to contain_exactly(
        :id, :username, :avatar_url, :distinct, :status, :creation_time
      )
    end

    # A Discord snowflake is wider than a JSON number can carry without losing its low digits, and this crosses
    # to the website as JSON.
    it "renders the id as a string" do
      expect(discord_user.to_h[:id]).to eq(discord_user.id.to_s)
    end

    it "carries the values Discordrb reports" do
      expect(discord_user.to_h).to include(
        username: discord_user.username,
        avatar_url: discord_user.avatar_url,
        distinct: discord_user.distinct
      )
    end

    it "is aliased as #attributes" do
      expect(discord_user.attributes).to eq(discord_user.to_h)
    end
  end
end
