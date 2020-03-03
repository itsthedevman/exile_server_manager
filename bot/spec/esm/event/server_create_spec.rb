# frozen_string_literal: true

describe ESM::Event::ServerCreate do
  let!(:event) { ESM::Event::ServerCreate.new(ServerCreateEvent.create) }

  it "should be valid" do
    expect(event).not_to be_nil
  end

  it "should create a community" do
    expect(ESM::Community.where(guild_id: ESM::Community::ESM::ID).first).not_to be_nil
  end

  it "should send server owner welcome" do
    ESM::Test.response = "yes"
    expect { event.run! }.not_to raise_error
    expect(ESM::Test.messages.size).to eql(2)

    # First message
    first_embed = ESM::Test.messages.first[1]
    expect(first_embed.title).to eql("**Hello #{ESM::User::Bryan::USERNAME}, thank you for inviting me to your community!**")
    expect(first_embed.description).to eql("I'm excited to get start, but first, I have a question to ask you.\nIt appears I was invited to and joined your Discord server, _Exile Server Manager_. Does your community host Exile Servers?")
    expect(first_embed.fields.size).to eql(1)
    expect(first_embed.fields.first.value).to eql("_Just reply back `yes` or `no` when you're ready_")

    # Second message
    second_embed = ESM::Test.messages.second[1]
    expect(second_embed.title).to eql("Welcome to the ESM Community!")
    expect(second_embed.description).to eql("Awesome! I've disabled player mode for you. This means you can now manage your community and servers in the server portal on our website. But first, I highly suggest taking a look at our [wiki](https://www.esmbot.com/wiki) for information on getting started. It also contains my [commands](https://www.esmbot.com/wiki/commands), and information about [Player Mode](https://www.esmbot.com/wiki/player_mode).")
    expect(second_embed.fields.size).to eql(3)
    expect(second_embed.fields.first.name).to eql("Admin Commands and Player Commands")
    expect(second_embed.fields.first.value).to eql("Every player command can be used in this channel freely, however, their usage in Discord servers may vary. Server admins can disable player commands from being ran in their Discord, but I will let you know when you can't use that command in that channel.\nAdmin Commands can **only** be used in a Discord server and they can only be used by roles specified by the Server admins.")
    expect(second_embed.fields.second.name).to eql("Need help?")
    expect(second_embed.fields.second.value).to eql("At any time, you can use the `~help` command for quick information. If you don't find your question, or if you have an issue, please join our discord and let us know :smile:")
    expect(second_embed.fields.third.name).to eql("One final thing, just in case")
    expect(second_embed.fields.third.value).to eql("If you meant to say _no_ to that question, you can enable player mode by sending me `~mode player`. I won't tell :wink:")
  end

  it "should send player welcome" do
    ESM::Test.response = "no"
    expect { event.run! }.not_to raise_error
    expect(ESM::Test.messages.size).to eql(2)

    # First message
    first_embed = ESM::Test.messages.first[1]
    expect(first_embed.title).to eql("**Hello #{ESM::User::Bryan::USERNAME}, thank you for inviting me to your community!**")
    expect(first_embed.description).to eql("I'm excited to get start, but first, I have a question to ask you.\nIt appears I was invited to and joined your Discord server, _Exile Server Manager_. Does your community host Exile Servers?")
    expect(first_embed.fields.size).to eql(1)
    expect(first_embed.fields.first.value).to eql("_Just reply back `yes` or `no` when you're ready_")

    # Second message
    second_embed = ESM::Test.messages.second[1]
    expect(second_embed.title).to eql("Welcome to the ESM Community!")
    expect(second_embed.description).to eql("Excellent! I've left player mode enabled so you and your friends can use my player commands in your Discord server. But first, I highly suggest taking a look at our [wiki](https://www.esmbot.com/wiki) for information on getting started. It also contains my [commands](https://www.esmbot.com/wiki/commands), and information about [Player Mode](https://www.esmbot.com/wiki/player_mode).")
    expect(second_embed.fields.size).to eql(3)
    expect(second_embed.fields.first.name).to eql("Admin Commands and Player Commands")
    expect(second_embed.fields.first.value).to eql("Every player command can be used in this channel freely, however, their usage in Discord servers may vary. Server admins can disable player commands from being ran in their Discord, but I will let you know when you can't use that command in that channel.\nAdmin Commands can **only** be used in a Discord server and they can only be used by roles specified by the Server admins.")
    expect(second_embed.fields.second.name).to eql("Need help?")
    expect(second_embed.fields.second.value).to eql("At any time, you can use the `~help` command for quick information. If you don't find your question, or if you have an issue, please join our discord and let us know :smile:")
    expect(second_embed.fields.third.name).to eql("One final thing, just in case")
    expect(second_embed.fields.third.value).to eql("If you meant to say _yes_ to that question, you can disable player mode by sending me `~mode server`. I won't tell :wink:")
  end
end
