# frozen_string_literal: true

describe ESM::Embed do
  it "should modify a embed with a title" do
    discord_embed = Discordrb::Webhooks::Embed.new

    esm_embed =
      ESM::Embed.build do |embed|
        embed.title = "Test embed"
      end

    esm_embed.transfer(discord_embed)
    expect(discord_embed.title).to eql("Test embed")
    expect(discord_embed.description).to be_nil
  end

  it "should store the correct values" do
    time = DateTime.now

    esm_embed =
      ESM::Embed.build do |embed|
        embed.title = "Test embed"
        embed.description = "Description"
        embed.url = "https://www.esmbot.com"
        embed.timestamp = time
        embed.color = "#3ED3FB"
        embed.set_footer(text: "hello", icon_url: 'https://i.imgur.com/j69wMDu.jpg')
        embed.image = 'https://i.imgur.com/PcMltU7.jpg'
        embed.thumbnail = 'https://i.imgur.com/xTG3a1I.jpg'
        embed.set_author(name: 'meew0', url: 'https://github.com/meew0', icon_url: 'https://avatars2.githubusercontent.com/u/3662915?v=3&s=466')
        embed.add_field(name: "name", value: "value", inline: true)
      end

    discord_embed = Discordrb::Webhooks::Embed.new
    esm_embed.transfer(discord_embed)

    expect(esm_embed.title).to eql("Test embed")
    expect(esm_embed.description).to eql("Description")
    expect(esm_embed.url).to eql("https://www.esmbot.com")
    expect(esm_embed.timestamp).to eql(time)
    expect(esm_embed.color).to eql("#3ED3FB")
    expect(esm_embed.footer.text).to eql("hello")
    expect(esm_embed.footer.icon_url).to eql('https://i.imgur.com/j69wMDu.jpg')
    expect(esm_embed.image.url).to be('https://i.imgur.com/PcMltU7.jpg')
    expect(esm_embed.thumbnail.url).to be('https://i.imgur.com/xTG3a1I.jpg')
    expect(esm_embed.author.name).to eql('meew0')
    expect(esm_embed.author.url).to eql('https://github.com/meew0')
    expect(esm_embed.author.icon_url).to eql('https://avatars2.githubusercontent.com/u/3662915?v=3&s=466')
    expect(esm_embed.fields.size).to eql(1)
    expect(esm_embed.fields.first.name).to eql("name")
    expect(esm_embed.fields.first.value).to eql("value")
    expect(esm_embed.fields.first.inline).to be(true)
  end

  it "transfers all attributes" do
    time = DateTime.now

    esm_embed =
      ESM::Embed.build do |embed|
        embed.title = "Test embed"
        embed.description = "Description"
        embed.url = "https://www.esmbot.com"
        embed.timestamp = time
        embed.color = "#3ED3FB"
        embed.set_footer(text: "hello", icon_url: 'https://i.imgur.com/j69wMDu.jpg')
        embed.image = 'https://i.imgur.com/PcMltU7.jpg'
        embed.thumbnail = 'https://i.imgur.com/xTG3a1I.jpg'
        embed.set_author(name: 'meew0', url: 'https://github.com/meew0', icon_url: 'https://avatars2.githubusercontent.com/u/3662915?v=3&s=466')
        embed.add_field(name: "name", value: "value", inline: true)
      end

    discord_embed = Discordrb::Webhooks::Embed.new
    esm_embed.transfer(discord_embed)

    expect(discord_embed.title).to eql("Test embed")
    expect(discord_embed.description).to eql("Description")
    expect(discord_embed.url).to eql("https://www.esmbot.com")
    expect(discord_embed.timestamp).to eql(time)
    expect(discord_embed.color).to eql(4_117_499)
    expect(discord_embed.footer.text).to eql("hello")
    expect(discord_embed.footer.icon_url).to eql('https://i.imgur.com/j69wMDu.jpg')
    expect(discord_embed.image.url).to be('https://i.imgur.com/PcMltU7.jpg')
    expect(discord_embed.thumbnail.url).to be('https://i.imgur.com/xTG3a1I.jpg')
    expect(discord_embed.author.name).to eql('meew0')
    expect(discord_embed.author.url).to eql('https://github.com/meew0')
    expect(discord_embed.author.icon_url).to eql('https://avatars2.githubusercontent.com/u/3662915?v=3&s=466')
    expect(discord_embed.fields.size).to eql(1)
    expect(discord_embed.fields.first.name).to eql("name")
    expect(discord_embed.fields.first.value).to eql("value")
    expect(discord_embed.fields.first.inline).to be(true)
  end

  it "should be valid with too much text" do
    a_very_large_text_block = "texttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttexttext"

    esm_embed =
      ESM::Embed.build do |embed|
        embed.title = a_very_large_text_block
        embed.description = a_very_large_text_block
        embed.add_field(
          name: a_very_large_text_block,
          value: a_very_large_text_block
        )
      end

    expect(esm_embed.title.size).to eql(ESM::Embed::Limit::TITLE_LENGTH_MAX)
    expect(esm_embed.description.size).to eql(ESM::Embed::Limit::DESCRIPTION_LENGTH_MAX)
    expect(esm_embed.fields.first.name.size).to eql(ESM::Embed::Limit::FIELD_NAME_LENGTH_MAX)
    expect(esm_embed.fields.first.value.size).to eql(ESM::Embed::Limit::FIELD_VALUE_LENGTH_MAX)
  end

  it "should have a single field with an \"empty\" name" do
    esm_embed =
      ESM::Embed.build do |embed|
        embed.add_field(
          value: "Foo"
        )
      end

    expect(esm_embed.fields.first.name).to eql("\u200B")
  end

  it "should accept an array as it's description" do
    embed =
      ESM::Embed.build do |e|
        e.description = [
          "First Line",
          "Second Line"
        ]
      end

    expect(embed.description).to eql("First Line\nSecond Line")
  end

  it "should have a footer" do
    embed =
      ESM::Embed.build do |e|
        e.footer = "test"
      end

    expect(embed.footer.text).to eql("test")
  end

  it "should have a valid color" do
    embed =
      ESM::Embed.build do |e|
        e.color = :blue
      end

    expect(embed.color).to eql(ESM::Color::Toast::BLUE)
  end

  describe "Build from Template" do
    it "should build an error template (title)" do
      embed = ESM::Embed.build(:error, title: "This is an error")

      expect(embed.color).to eql(ESM::Color::Toast::RED)
      expect(embed.title).to eql("This is an error")
      expect(embed.description).to be_blank
    end

    it "should build an error template (description)" do
      embed = ESM::Embed.build(:error, description: "This is an error")

      expect(embed.color).to eql(ESM::Color::Toast::RED)
      expect(embed.description).to eql("This is an error")
      expect(embed.title).to be_blank
    end
  end



  describe "#to_s" do
    it "should return all available information" do
      time = DateTime.now

      embed =
        ESM::Embed.build do |e|
          e.description = "Testing Description"
          e.add_field(
            name: "Field 1",
            value: "Field 1"
          )
        end

      expect(embed.to_s).to eql("Description (19): Testing Description\nFields:\n\t#1\n\t  Name (7): Field 1\n\t  Value (7): Field 1\nMetadata:\n\tTimestamp: #{time}\n\tColor: #3ED3FB\n")
    end

    it "should return all information" do
      time = DateTime.now

      embed =
        ESM::Embed.build do |embed|
          embed.title = "Test embed"
          embed.description = "Description"
          embed.url = "https://www.esmbot.com"
          embed.timestamp = time
          embed.color = "#3ED3FB"
          embed.set_footer(text: "hello", icon_url: 'https://i.imgur.com/j69wMDu.jpg')
          embed.image = 'https://i.imgur.com/PcMltU7.jpg'
          embed.thumbnail = 'https://i.imgur.com/xTG3a1I.jpg'
          embed.set_author(name: 'meew0', url: 'https://github.com/meew0', icon_url: 'https://avatars2.githubusercontent.com/u/3662915?v=3&s=466')
          embed.add_field(name: "name", value: "value", inline: true)
        end

      expect(embed.to_s).to eql("Title (10): Test embed\nDescription (11): Description\nFields:\n\t#1 <inline>\n\t  Name (4): name\n\t  Value (5): value\nMetadata:\n\tTimestamp: #{time}\n\tColor: #3ED3FB\n\tImage: https://i.imgur.com/PcMltU7.jpg\n\tThumbnail: https://i.imgur.com/xTG3a1I.jpg\n\tURL: https://www.esmbot.com\n\tFooter: hello")
    end
  end

  describe "#add_field_array" do
    it "should have tests"
  end

  describe "#store_field" do
    it "should have tests"
  end
end
