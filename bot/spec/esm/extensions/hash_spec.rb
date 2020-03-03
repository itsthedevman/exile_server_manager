# frozen_string_literal: true

describe Hash do
  it "should convert to OpenStruct" do
    obj = { foo: "bar" }.to_ostruct
    expect(obj).not_to be_nil
    expect(obj).to be_a(OpenStruct)
    expect(obj.foo).to eql("bar")
  end

  it "should be recursive" do
    obj = { foo: { bar: { baz: true } } }.to_ostruct
    expect(obj).not_to be_nil
    expect(obj).to be_a(OpenStruct)
    expect(obj.foo).to be_a(OpenStruct)
    expect(obj.foo.bar).to be_a(OpenStruct)
    expect(obj.foo.bar.baz).to be(true)
  end
end
