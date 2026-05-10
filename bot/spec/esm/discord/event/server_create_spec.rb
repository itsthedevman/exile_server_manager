# frozen_string_literal: true

describe ESM::Discord::Event::ServerCreate do
  let(:discord_server) { build(:discord_server) }
  let!(:event) { ESM::Discord::Event::ServerCreate.new(discord_server) }
  let(:community) { ESM::Community.find_by_guild_id(discord_server.id.to_s) }

  it "should be valid" do
    expect(event).not_to be_nil
  end

  it "should create a community" do
    expect(community).not_to be_nil
  end

  it "should send server owner welcome" do
    expect { event.run! }.not_to raise_error
    ESM.discord_bot.test_outbox.await_size(1)

    embed = ESM.discord_bot.test_outbox.first.content
    expect(embed.title).to match(/thank you for inviting me/i)
    expect(embed.description).to eq("If this is your first time inviting me, please read my [Getting Started](https://www.esmbot.com/wiki) guide. It goes over how to use my commands and any extra setup that may need done. You can also use the `/help` command if you need detailed information on how to use a command.\nIf you encounter a bug, please join my developer's [Discord Server](https://www.esmbot.com/join) and let him know in the support channel :smile:\n\n**If you host Exile Servers, please read the following message**\n||In order for players to run commands on your servers, I've assigned you `#{community.community_id}` as your community ID. This ID will be used in commands to let players distinguish which community they want run the command on.\nDon't worry about memorizing it quite yet. You can always change it later via the [Admin Dashboard](https://www.esmbot.com/dashboard).\nOne more thing, before you can link your servers with me, I'll need you to disable [Player Mode](https://www.esmbot.com/wiki/player_mode). Please reply back to this message with `/community admin change_mode for:#{community.community_id}`||")
  end

  it "will update the community's owner ID" do 
    expect(community.owner_user_id).to be_nil

    event.run!
    community.reload

    expect(community.owner_user_id).not_to be_nil
  end
end
