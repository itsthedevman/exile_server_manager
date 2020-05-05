# frozen_string_literal: true

describe ESM::Command::Argument::Parser do
  let!(:parser_klass) { ESM::Command::Argument::Parser }

  describe "Parsing" do
    it "1" do
      argument = ESM::Command::Argument.new(:test, regex: /test/, description: "d")

      parser = parser_klass.new(argument, "test")
      expect(parser.value).to eql("test")
    end

    it "2" do
      argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d")

      parser = parser_klass.new(argument, "12345")
      expect(parser.value).to eql("12345")
    end
  end

  it "should default" do
    argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d", default: "testing")

    parser = parser_klass.new(argument, "")
    expect(parser.value).to eql("testing")
  end

  describe "Type-casting" do
    it "should be string" do
      argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d")

      parser = parser_klass.new(argument, "testing")
      expect(parser.value).to eql("testing")
    end

    it "should be integer" do
      argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d", type: :integer)

      parser = parser_klass.new(argument, "1")
      expect(parser.value).to eql(1)
    end

    it "should be float" do
      argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d", type: :float)

      parser = parser_klass.new(argument, "2.5")
      expect(parser.value).to eql(2.5)
    end

    it "should be json" do
      argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d", type: :json)

      parser = parser_klass.new(argument, '{ "foo": "bar" }')
      expect(parser.value).to have_key("foo")
      expect(parser.value["foo"]).to eql("bar")
    end

    it "should be symbol" do
      argument = ESM::Command::Argument.new(:test, regex: /.*/, description: "d", type: :symbol)

      parser = parser_klass.new(argument, "testing")
      expect(parser.value).to eql(:testing)
    end
  end
end
