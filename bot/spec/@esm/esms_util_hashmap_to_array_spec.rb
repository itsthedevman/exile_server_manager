# frozen_string_literal: true

describe "ESMs_util_hashmap_toArray", :requires_connection, v2: true do
  include_context "connection"

  it "converts the array to a hashmap" do
    response = execute_sqf!(
      <<~SQF
        private _footLongSubHashmap = createHashMapFromArray [["key_6", 6], ["key_7", 7]];
        private _subHashmap = createHashMapFromArray [["key_4", [4]], ["key_5", _footLongSubHashmap]];
        private _hashmap = createHashMapFromArray [["key_1", "value_1"], ["key_2", true], ["key_3", _subHashmap]];

        _result = _hashMap call ESMs_util_hashmap_toArray;
        if (isNil "_result") exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["key_1", "value_1"], ["key_2", true], ["key_3", [["key_4", [4]], ["key_5", [["key_6", 6], ["key_7", 7]]]]]])
  end

  it "converts an array of hashmaps" do
    response = execute_sqf!(
      <<~SQF
        private _array = [];
        _array pushBack (createHashMapFromArray [["key_1", "value_1"], ["key_2", "value_2"]]);

        private _hashmap = createHashMapFromArray [["1", "11"]];
        _array pushBack [(createHashMapFromArray [["sub_key_1", "sub_value_1"], ["sub_key_2", [_hashmap]]])];

        _result = _array call ESMs_util_hashmap_toArray;
        if (isNil "_result") exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil

    # For whatever reason, Arma wants to sort the entries in the second Hash like that
    expect(response.data.result).to eq([
      [["key_1", "value_1"], ["key_2", "value_2"]],
      [[["sub_key_2", [[["1", "11"]]]], ["sub_key_1", "sub_value_1"]]]
    ])
  end
end
