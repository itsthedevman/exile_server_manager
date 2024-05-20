# frozen_string_literal: true

describe Inquirer do
  context "when there is only one predicate provided" do
    subject(:inquirer) { described_class.new(:foo) }

    it "initializes" do
      expect(inquirer).to be_instance_of(described_class)
      expect(inquirer.foo?).to be(false)
    end
  end

  context "when there are more than one predicates provided" do
    subject(:inquirer) { described_class.new(:foo, :bar) }

    it "initializes" do
      expect(inquirer).to be_instance_of(described_class)
      expect(inquirer.foo?).to be(false)
      expect(inquirer.bar?).to be(false)
    end
  end

  context "when a symbol is provided as the default" do
    subject(:inquirer) { described_class.new(:foo, :bar, default: :bar) }

    it "sets the provided predicate to true" do
      expect(inquirer.foo?).to be(false)
      expect(inquirer.bar?).to be(true)
    end
  end

  context "when an array is provided as the default" do
    subject(:inquirer) { described_class.new(:foo, :bar, :baz, default: [:foo, :bar]) }

    it "sets all provided predicates to true" do
      expect(inquirer.foo?).to be(true)
      expect(inquirer.bar?).to be(true)
      expect(inquirer.baz?).to be(false)
    end
  end

  describe "#set" do
    context "when predicates are provided" do
      subject(:inquirer) { described_class.new(:foo, :bar, :baz) }

      it "sets all provided predicates to true" do
        expect(inquirer.foo?).to be(false)
        expect(inquirer.bar?).to be(false)
        expect(inquirer.baz?).to be(false)

        inquirer.set(:foo, :baz)

        expect(inquirer.foo?).to be(true)
        expect(inquirer.bar?).to be(false)
        expect(inquirer.baz?).to be(true)
      end
    end

    context "when a Symbol is provided for :unset" do
      subject(:inquirer) { described_class.new(:foo, :bar, :baz) }

      it "un-sets the predicate" do
        inquirer.set(:foo)

        expect(inquirer.foo?).to be(true)
        expect(inquirer.bar?).to be(false)
        expect(inquirer.baz?).to be(false)

        inquirer.set(:bar, :baz, unset: :foo)

        expect(inquirer.foo?).to be(false)
        expect(inquirer.bar?).to be(true)
        expect(inquirer.baz?).to be(true)
      end
    end

    context "when true is provided for :unset (default functionality)" do
      subject(:inquirer) { described_class.new(:foo, :bar, :baz) }

      it "un-sets all other predicates" do
        inquirer.set(:foo, :baz)

        expect(inquirer.foo?).to be(true)
        expect(inquirer.bar?).to be(false)
        expect(inquirer.baz?).to be(true)

        inquirer.set(:bar)

        expect(inquirer.foo?).to be(false)
        expect(inquirer.bar?).to be(true)
        expect(inquirer.baz?).to be(false)
      end
    end

    context "when false is provided for :unset" do
      subject(:inquirer) { described_class.new(:foo, :bar, :baz) }

      it "does not modify the other predicates" do
        inquirer.set(:foo, :baz)

        expect(inquirer.foo?).to be(true)
        expect(inquirer.bar?).to be(false)
        expect(inquirer.baz?).to be(true)

        inquirer.set(:bar, unset: false)

        expect(inquirer.foo?).to be(true)
        expect(inquirer.bar?).to be(true)
        expect(inquirer.baz?).to be(true)
      end
    end

    context "when predicates are provided for :unset" do
      subject(:inquirer) { described_class.new(:foo, :bar, :baz) }

      it "does not modify the other predicates" do
        inquirer.set(:foo, :baz)

        expect(inquirer.foo?).to be(true)
        expect(inquirer.bar?).to be(false)
        expect(inquirer.baz?).to be(true)

        inquirer.set(:bar, unset: [:foo])

        expect(inquirer.foo?).to be(false)
        expect(inquirer.bar?).to be(true)
        expect(inquirer.baz?).to be(true)
      end
    end
  end
end
