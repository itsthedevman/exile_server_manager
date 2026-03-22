# frozen_string_literal: true

describe String do
  describe "#to_ostruct" do
    let!(:struct) { {string: "string", boolean: false, array: %w[foo bar], object: {recursive: {oh: "wow"}}}.to_json.to_ostruct }

    it "is OpenStruct" do
      expect(struct).to be_kind_of(OpenStruct)
    end

    it "is string" do
      expect(struct.string).to eq("string")
    end

    it "is boolean" do
      expect(struct.boolean).to be(false)
    end

    it "is array" do
      expect(struct.array.size).to eq(2)
      expect(struct.array.first).to eq("foo")
      expect(struct.array.second).to eq("bar")
    end

    it "is hash (recursive)" do
      expect(struct.object&.recursive&.oh).to eq("wow")
    end
  end

  describe "#to_h" do
    let!(:hash) { {string: "string", boolean: false, array: %w[foo bar], object: {recursive: {oh: "wow"}}}.to_json.to_h }

    it "is Hash" do
      expect(hash).to be_kind_of(Hash)
    end

    it "is string" do
      expect(hash[:string]).to eq("string")
    end

    it "is boolean" do
      expect(hash[:boolean]).to be(false)
    end

    it "is array" do
      expect(hash[:array].size).to eq(2)
      expect(hash[:array].first).to eq("foo")
      expect(hash[:array].second).to eq("bar")
    end

    it "is hash (recursive)" do
      expect(hash[:object][:recursive][:oh]).to eq("wow")
    end
  end

  describe "#to_poptab" do
    it "converts" do
      expect("10000".to_poptab).to eq("10,000 poptabs")
    end

    it "is singular" do
      expect("1".to_poptab).to eq("1 poptab")
    end
  end

  describe "#to_readable" do
    it "converts" do
      expect("1983434552".to_readable).to eq("1,983,434,552")
    end
  end

  describe "#steam_uid?" do
    let(:user) { ESM::Test.user }

    it "returns true" do
      expect(user.steam_uid.steam_uid?).to be(true)
    end

    it "returns false" do
      expect(user.discord_id.steam_uid?).to be(false)
    end
  end

  describe "#to_deep_h" do 
    describe "with invalid JSON" do
      it "returns nil" do
        expect("not valid json".to_deep_h).to be_nil
      end
    end

    describe "with simple JSON" do
      it "parses basic hash" do
        json = {name: "Alice", age: 30}.to_json

        expect(json.to_deep_h).to eq({name: "Alice", age: 30})
      end

      it "parses basic array" do
        json = [1, 2, 3].to_json

        expect(json.to_deep_h).to eq([1, 2, 3])
      end
    end

    describe "with nested JSON strings" do
      it "recursively parses nested JSON in hash values" do
        json = {
          profile: {role: "admin", permissions: {read: true, write: true}.to_json}.to_json
        }.to_json

        expect(json.to_deep_h).to eq({
          profile: {
            role: "admin",
            permissions: {read: true, write: true}
          }
        })
      end

      it "recursively parses deeply nested JSON" do
        json = {
          a: {
            b: [
              {c: 1},
              {d: 2}.to_json
            ]
          }
        }.to_json

        expect(json.to_deep_h).to eq({
          a: {
            b: [
              {c: 1},
              {d: 2}
            ]
          }
        })
      end

      it "handles multiple levels of nested JSON strings" do
        json = {
          user: {
            name: "Alice",
            metadata: {
              profile: {
                role: "admin",
                permissions: {read: true, write: true}.to_json
              }.to_json
            }
          }
        }.to_json

        expect(json.to_deep_h).to eq({
          user: {
            name: "Alice",
            metadata: {
              profile: {
                role: "admin",
                permissions: {read: true, write: true}
              }
            }
          }
        })
      end
    end

    describe "with arrays" do
      it "handles arrays with nested JSON strings" do
        json = [
          {profile: {level: "expert"}.to_json},
          {config: {enabled: true}.to_json}
        ].to_json

        expect(json.to_deep_h).to eq([
          {profile: {level: "expert"}},
          {config: {enabled: true}}
        ])
      end

      it "handles nested arrays" do
        json = [
          [1, 2, [3, 4]],
          {nested: [5, 6].to_json}
        ].to_json

        expect(json.to_deep_h).to eq([
          [1, 2, [3, 4]],
          {nested: [5, 6]}
        ])
      end

      it "preserves non-JSON strings in arrays" do
        json = [
          "plain string",
          {name: "Alice"}
        ].to_json

        expect(json.to_deep_h).to eq([
          "plain string",
          {name: "Alice"}
        ])
      end
    end

    describe "with mixed types" do
      it "preserves primitive types" do
        json = {
          string: "hello",
          number: 42,
          float: 3.14,
          boolean: true,
          null_value: nil
        }.to_json

        expect(json.to_deep_h).to eq({
          string: "hello",
          number: 42,
          float: 3.14,
          boolean: true,
          null_value: nil
        })
      end

      it "handles complex mixed structures" do
        json = {
          users: [
            {name: "Alice", roles: ["admin", "user"].to_json},
            {name: "Bob", roles: ["user"].to_json}
          ],
          metadata: {
            created_at: "2025-01-01",
            config: {debug: false}.to_json
          }
        }.to_json

        expect(json.to_deep_h).to eq({
          users: [
            {name: "Alice", roles: ["admin", "user"]},
            {name: "Bob", roles: ["user"]}
          ],
          metadata: {
            created_at: "2025-01-01",
            config: {debug: false}
          }
        })
      end
    end

    describe "with Struct serialized to JSON" do
      it "parses JSON from Struct#to_h" do
        address_struct = Struct.new(:city, :country)
        person_struct = Struct.new(:name, :address, :roles)

        person = person_struct.new(
          "Bob",
          address_struct.new("New York", "USA"),
          ["admin", "user"]
        )

        json = person.to_json

        expect(json.to_deep_h).to eq({
          name: "Bob",
          address: {city: "New York", country: "USA"},
          roles: ["admin", "user"]
        })
      end
    end

    describe "with OpenStruct serialized to JSON" do
      it "parses JSON from OpenStruct#to_h" do
        address = OpenStruct.new(city: "New York", country: "USA")
        person = OpenStruct.new(
          name: "Bob",
          address: address.to_h,
          roles: ["admin", "user"]
        )

        json = person.to_h.to_json

        expect(json.to_deep_h).to eq({
          name: "Bob",
          address: {city: "New York", country: "USA"},
          roles: ["admin", "user"]
        })
      end
    end

    describe "with Data serialized to JSON" do
      it "parses JSON from Data#to_h" do
        address_data = Data.define(:city, :country)
        person_data = Data.define(:name, :address, :roles)

        address = address_data.new(city: "New York", country: "USA")
        person = person_data.new(
          name: "Bob",
          address: address.to_h,
          roles: ["admin", "user"]
        )

        json = person.to_h.to_json

        expect(json.to_deep_h).to eq({
          name: "Bob",
          address: {city: "New York", country: "USA"},
          roles: ["admin", "user"]
        })
      end
    end
  end
end
