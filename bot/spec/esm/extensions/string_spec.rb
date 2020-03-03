# frozen_string_literal: true

describe String do
  describe "#to_ostruct" do
    let!(:struct) { { string: "string", boolean: false, array: %w[foo bar], object: { recursive: { oh: "wow" } } }.to_json.to_ostruct }

    it "should be of type OpenStruct" do
      expect(struct).to be_kind_of(OpenStruct)
    end

    it "should be string" do
      expect(struct.string).to eql("string")
    end

    it "should be boolean" do
      expect(struct.boolean).to be(false)
    end

    it "should be array" do
      expect(struct.array.size).to eql(2)
      expect(struct.array.first).to eql("foo")
      expect(struct.array.second).to eql("bar")
    end

    it "should be hash (recursive)" do
      expect(struct.object&.recursive&.oh).to eql("wow")
    end
  end

  describe "#to_h" do
    let!(:hash) { { string: "string", boolean: false, array: %w[foo bar], object: { recursive: { oh: "wow" } } }.to_json.to_h }

    it "should be of type Hash" do
      expect(hash).to be_kind_of(Hash)
    end

    it "should be string" do
      expect(hash[:string]).to eql("string")
    end

    it "should be boolean" do
      expect(hash[:boolean]).to be(false)
    end

    it "should be array" do
      expect(hash[:array].size).to eql(2)
      expect(hash[:array].first).to eql("foo")
      expect(hash[:array].second).to eql("bar")
    end

    it "should be hash (recursive)" do
      expect(hash[:object][:recursive][:oh]).to eql("wow")
    end
  end

  describe "#to_poptab" do
    it "should convert" do
      expect("10000".to_poptab).to eql("10,000 poptabs")
    end

    it "should be singular" do
      expect("1".to_poptab).to eql("1 poptab")
    end
  end

  describe "#to_readable" do
    it "should convert" do
      expect("1983434552".to_readable).to eql("1,983,434,552")
    end
  end
end
