# frozen_string_literal: true

describe Hash do
  describe "#map_join" do
    context "when no join_with is provided" do
      it "joins without anything in-between" do
        result = {a: 1, b: 2}.map_join { |k, v| k.to_s + v.to_s }
        expect(result).to eq("a1b2")
      end
    end

    context "when join_with is provided" do
      it "joins with the value in-between" do
        result = {a: 1, b: 2}.map_join(" ") { |k, v| k.to_s + v.to_s }
        expect(result).to eq("a1 b2")
      end
    end
  end

  describe "#to_struct" do
    it "converts to Struct" do
      obj = {foo: "bar"}.to_struct
      expect(obj).not_to be_nil
      expect(obj).to be_a(Struct)
      expect(obj.foo).to eq("bar")
    end

    it "is recursive" do
      obj = {foo: {bar: {baz: true}}}.to_struct
      expect(obj).not_to be_nil
      expect(obj).to be_a(Struct)
      expect(obj.foo).to be_a(Struct)
      expect(obj.foo.bar).to be_a(Struct)
      expect(obj.foo.bar.baz).to be(true)
    end

    it "preserves ruby classes" do
      input = {time: Time.current}
      output = input.to_struct
      expect(output).not_to be_nil
      expect(output).to be_a(Struct)
      expect(output.time).to eq(input[:time])
    end
  end

  describe "#to_ostruct" do
    it "converts to OpenStruct" do
      obj = {foo: "bar"}.to_ostruct
      expect(obj).not_to be_nil
      expect(obj).to be_a(OpenStruct)
      expect(obj.foo).to eq("bar")
    end

    it "is recursive" do
      obj = {foo: {bar: {baz: true}}}.to_ostruct
      expect(obj).not_to be_nil
      expect(obj).to be_a(OpenStruct)
      expect(obj.foo).to be_a(OpenStruct)
      expect(obj.foo.bar).to be_a(OpenStruct)
      expect(obj.foo.bar.baz).to be(true)
    end

    it "preserves ruby classes" do
      input = {time: Time.current}
      output = input.to_ostruct
      expect(output).not_to be_nil
      expect(output).to be_a(OpenStruct)
      expect(output.time).to eq(input[:time])
    end
  end

  describe "#to_istruct" do
    it "converts to Data" do
      obj = {foo: "bar"}.to_istruct
      expect(obj).not_to be_nil
      expect(obj).to be_a(Data)
      expect(obj.foo).to eq("bar")
    end

    it "is recursive" do
      obj = {foo: {bar: {baz: true}}}.to_istruct
      expect(obj).not_to be_nil
      expect(obj).to be_a(Data)
      expect(obj.foo).to be_a(Data)
      expect(obj.foo.bar).to be_a(Data)
      expect(obj.foo.bar.baz).to be(true)
    end

    it "preserves ruby classes" do
      input = {time: Time.current}
      output = input.to_istruct
      expect(output).not_to be_nil
      expect(output).to be_a(Data)
      expect(output.time).to eq(input[:time])
    end
  end
end
