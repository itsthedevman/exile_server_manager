# frozen_string_literal: true

RSpec.describe ESM::Command::Server::Broadcast::Audience do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }

  # A cooldown row is the record that someone has played on a server, so writing one is how these examples say
  # "this player is known to this server".
  def played_on(server, user:, registered: true)
    create(
      :cooldown,
      user_id: user.id,
      server_id: server.id,
      community_id: server.community_id,
      steam_uid: registered ? user.steam_uid : nil,
      command_name: "me"
    )
  end

  def opted_out_of(server, user:)
    ESM::UserNotificationPreference.create!(user_id: user.id, server_id: server.id, custom: false)
  end

  describe ".for" do
    it "reaches a player who has run a command for the server" do
      user = create(:user)
      played_on(server, user:)

      expect(described_class.for([server])).to contain_exactly(user)
    end

    it "reaches nobody on a server no one has played on" do
      create(:user)

      expect(described_class.for([server])).to be_empty
    end

    it "leaves out a player who turned custom notifications off for that server" do
      user = create(:user)
      played_on(server, user:)
      opted_out_of(server, user:)

      expect(described_class.for([server])).to be_empty
    end

    it "still reaches a player who opted out of a different server" do
      other_server = create(:server, community:)
      user = create(:user)
      played_on(server, user:)
      played_on(other_server, user:)
      opted_out_of(other_server, user:)

      expect(described_class.for([server])).to contain_exactly(user)
    end

    # The reason this lives in one place: an audience size is a union, so a "3 servers" broadcast that summed its
    # per-server counts would promise more messages than it sends.
    it "counts a player on several servers once" do
      other_server = create(:server, community:)
      user = create(:user)
      played_on(server, user:)
      played_on(other_server, user:)

      expect(described_class.for([server, other_server])).to contain_exactly(user)
    end

    it "reaches a player known only by their steam uid" do
      user = create(:user)
      create(
        :cooldown,
        user_id: nil,
        server_id: server.id,
        community_id: server.community_id,
        steam_uid: user.steam_uid,
        command_name: "me"
      )

      expect(described_class.for([server])).to contain_exactly(user)
    end
  end
end
