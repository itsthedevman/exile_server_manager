# frozen_string_literal: true

describe ESM do
  it "loads the config" do
    expect(ESM.config).not_to be_nil
  end

  it "loads ENV" do
    expect(ESM.env.test?).to be(true)
  end

  it "has a valid bot" do
    expect(ESM.discord_bot).not_to be_nil
  end

  it "has i18n loaded" do
    expect(I18n.t(:test)).to eq("This is a test")
  end
end
