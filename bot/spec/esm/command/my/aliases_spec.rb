# frozen_string_literal: true

describe ESM::Command::My::Aliases, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is a player command" do
    expect(command.type).to eq(:player)
  end

  # Delete one, keep the other
  it "requires registration" do
    expect(command.registration_required?).to be(true)
  end

  describe "#on_execute/#on_response" do
    context "when the user has no aliases" do
      it "informs the user" do
        execute!

        latest_message.tap do |embed|
          expect(embed.title).to eq("My aliases")
          expect(embed.description).to eq(
            "You do not have any aliases, yet. *Aliases can be managed from the [player dashboard](https://esmbot.com/users/#{user.discord_id}/edit#id_aliases)*"
          )
        end
      end
    end

    context "when the user has server aliases" do
      let!(:user_alias) { create(:user_alias, user: user, server: server) }

      it "shows the server aliases in a table" do
        execute!

        latest_message.tap do |embed|
          expect(embed.title).to eq("My aliases")
          expect(embed.description).to include(
            user_alias.value,
            server.server_id,
            server.server_name,
            "Aliases can be managed"
          )
          expect(embed.description).not_to include("Communities")
        end
      end
    end

    context "when the user has community aliases" do
      let!(:user_alias) { create(:user_alias, user: user, community: community) }

      it "shows the community aliases in a table" do
        execute!

        latest_message.tap do |embed|
          expect(embed.title).to eq("My aliases")
          expect(embed.description).to include(
            user_alias.value,
            community.community_id,
            community.community_name,
            "Aliases can be managed"
          )
          expect(embed.description).not_to include("Servers")
        end
      end
    end

    context "when the user has server and community aliases" do
      let!(:community_alias) { create(:user_alias, user: user, community: community) }
      let!(:server_alias) { create(:user_alias, user: user, server: server) }

      it "shows both the community and server aliases in separate tables" do
        execute!

        latest_message.tap do |embed|
          expect(embed.title).to eq("My aliases")
          expect(embed.description).to include(
            "Community Aliases",
            community_alias.value,
            community.community_id,
            community.community_name.truncate(20),
            "Server Aliases",
            server_alias.value,
            server.server_id,
            server.server_name.truncate(20),
            "Aliases can be managed"
          )
        end
      end
    end
  end
end
