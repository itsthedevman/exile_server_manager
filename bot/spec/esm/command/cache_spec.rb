# frozen_string_literal: true

describe ESM::Command::Cache do
  it "should create a valid cache" do
    cache = ESM::Command::Cache.new(
      name: "name",
      type: "type",
      category: "category",
      description: "description",
      arguments: "arguments",
      examples: "examples",
      usage: "usage"
    )

    expect(cache.name).to eql("name")
    expect(cache.type).to eql("type")
    expect(cache.category).to eql("category")
    expect(cache.description).to eql("description")
    expect(cache.arguments).to eql("arguments")
    expect(cache.examples).to eql("examples")
    expect(cache.usage).to eql("usage")
  end
end
