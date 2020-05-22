# frozen_string_literal: true

describe ESM::Event::ServerCreate do
  let!(:event) { ESM::Event::ServerCreate.new(ESM.bot.server(ESM::Community::ESM::ID)) }
  let(:community) { ESM::Community.find_by_guild_id(ESM::Community::ESM::ID) }

  it "should be valid" do
    expect(event).not_to be_nil
  end

  it "should create a community" do
    expect(community).not_to be_nil
  end

  it "should send server owner welcome" do
    expect { event.run! }.not_to raise_error
    expect(ESM::Test.messages.size).to eql(1)

    embed = ESM::Test.messages.first.second
    expect(embed.title).to match(/thank you for inviting me/i)
    expect(embed.description).to eql("If this is your first time inviting me, please read my [Getting Started](https://www.esmbot.com/wiki) guide. It goes over how to use my commands and any extra setup that may need done. You can also use the `#{ESM.config.prefix}help` command if you need detailed information on how to use a command.\nIf you encounter a bug, please join my developer's [Discord Server](https://www.esmbot.com/join) and let him know in the support channel :smile:\n\n**If you host Exile Servers, please read the following message**\n||In order for players to run commands on your servers, I've assigned you `#{community.community_id}` as your community ID. This ID will be used in commands to let players distinguish which community they want run the command on.\nDon't worry about memorizing it quite yet. You can always change it later via the [Admin Dashboard](https://www.esmbot.com/login).\nOne more thing, before you can link your servers with me, I'll need you to disable [Player Mode](https://www.esmbot.com/wiki/player_mode). Please reply back to this message with `#{ESM.config.prefix}mode server`||")
  end
end
