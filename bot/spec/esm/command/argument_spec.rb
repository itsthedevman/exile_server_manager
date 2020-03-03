# frozen_string_literal: true

describe ESM::Command::Argument do
  describe "Valid Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /foo/, description: "Test") }

    it "should be a valid argument" do
      expect(argument).not_to be_nil
    end

    it "should have regex" do
      expect(argument.regex).not_to be_nil
      expect(argument.regex.source).to eql("foo")
    end
  end

  describe "Invalid Argument (missing regex)" do
    it "should raise error" do
      expect { ESM::Command::Argument.new(:foo) }.to raise_error("Missing regex for argument :foo", description: "Test")
    end
  end

  describe "Invalid Argument (missing description)"

  describe "Display Name Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /foo/, display_as: "FOOBAR", description: "Test") }

    it "should have a different display name" do
      expect(argument.display_as).not_to be_nil
      expect(argument.display_as).to eql("FOOBAR")
      expect(argument.name).not_to eql(argument.display_as)
    end
  end

  describe "Type Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /12345/, type: :integer, description: "Test") }

    it "should be a integer" do
      expect(argument.type).to eql(:integer)
    end
  end

  describe "Case Preserved Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /Foo/, preserve: true, description: "Test") }

    it "should preserve it's case" do
      expect(argument.preserve_case?).to be(true)
    end
  end

  describe "Mutliline Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /[\s\S]+/, multiline: true, description: "Test") }

    it "should be multiline" do
      expect(argument.multiline?).to be(true)
    end
  end

  describe "Default Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /hello/, default: "Hello World", description: "Test") }

    it "should have a default value" do
      expect(argument.default?).to be(true)
      expect(argument.default).to be("Hello World")
    end

    it "should not be required" do
      expect(argument.required?).to be(false)
    end
  end

  describe "Description Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /hello/, description: "Hello world") }

    it "should have a description" do
      expect(argument.description).to be("Hello world")
    end
  end

  describe "Argument with default values" do
    let(:argument) { ESM::Command::Argument.new(:foo, regex: /.+/, description: "Test") }

    it "should not preserve case" do
      expect(argument.preserve_case?).to be(false)
    end

    it "should be required" do
      expect(argument.required?).to be(true)
    end

    it "should be a string" do
      expect(argument.type).to eql(:string)
    end

    it "should have a display name" do
      expect(argument.display_as).to eql("foo")
    end

    it "should have a nil default" do
      expect(argument.default).to be_nil
    end

    it "should not have a default" do
      expect(argument.default?).to be(false)
    end

    it "should have a description" do
      expect(argument.description).to be("Test")
    end
  end

  describe "#to_s" do
    it "should be a standard argument" do
      argument = ESM::Command::Argument.new(:foo, regex: /.+/, description: "Test")
      expect(argument.to_s).to eql("<foo>")
    end

    it "should be an optional argument" do
      argument = ESM::Command::Argument.new(:foo, regex: /.+/, default: "foobar", description: "Test")
      expect(argument.to_s).to eql("<?foo>")
    end

    it "should use the display_as" do
      argument = ESM::Command::Argument.new(:foo, regex: /.+/, display_as: "bar", description: "Test")
      expect(argument.to_s).to eql("<bar>")
    end
  end
end
