# frozen_string_literal: true

describe ESM do
  it "should load the config" do
    expect(ESM.config).not_to be_nil
  end

  it "should load ENV" do
    expect(ESM.env.test?).to be(true)
  end

  it "should have a valid bot" do
    expect(ESM.bot).not_to be_nil
  end

  it "should have i18n loaded" do
    expect(I18n.t(:test)).to eq("This is a test")
  end
end
