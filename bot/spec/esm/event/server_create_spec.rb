# frozen_string_literal: true

describe ESM::Event::ServerCreate do
  let!(:event) { ESM::Event::ServerCreate.new(ESM.bot.server(ESM::Community::ESM::ID)) }

  it "should be valid" do
    expect(event).not_to be_nil
  end

  it "should create a community" do
    expect(ESM::Community.where(guild_id: ESM::Community::ESM::ID).first).not_to be_nil
  end

  it "should send server owner welcome" do
    expect { event.run! }.not_to raise_error
    expect(ESM::Test.messages.size).to eql(1)

    embed = ESM::Test.messages.first.second
    expect(embed.title).to match(/thank you for inviting me/i)
    expect(embed.description).to match(/if you intend to have players use commands on your servers, please reply back to this message/i)
  end
end
