# frozen_string_literal: true

describe "ESMs_util_hashmap_fromArray", requires_connection: true, v2: true do
  include_context "connection"

  it "does not convert the array" do
    response = execute_sqf!(
      <<~SQF
        private _result = [
          ["key_1", "key_2", "key_3"],
          [
            "value_1",
            true,
            [
              ["key_4", "key_5"],
              [
                false,
                [
                  ["key_6", "key_7"],
                  [6, nil]
                ]
              ]
            ]
          ]
        ] call ESMs_util_hashmap_fromArray;

        if (isNil "_result") exitWith {};
        if !(_result isEqualType createHashMap) exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to be_nil
  end

  it "converts the array to a hashmap" do
    response = execute_sqf!(
      <<~SQF
        private _result = [
          ["key_1", "value_1"],
          ["key_2", true],
          [
            "key_3",
            [
              ["key_4", false],
              [
                "key_5",
                [
                  ["key_6", 6],
                  ["key_7", nil]
                ]
              ]
            ]
          ]
        ] call ESMs_util_hashmap_fromArray;

        if (isNil "_result") exitWith {};
        if !(_result isEqualType createHashMap) exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq('[["key_1","value_1"],["key_2",true],["key_3",[["key_4",false],["key_5",[["key_6",6],["key_7",any]]]]]]')
  end

  it "handles nils" do
    response = execute_sqf!(
      <<~SQF
        [
          ["key_1", nil],
          ["key_2", 2],
          ["key_3", nil],
          ["key_4", 4]
        ] call ESMs_util_hashmap_fromArray
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq("[[\"key_1\",any],[\"key_2\",2],[\"key_3\",any],[\"key_4\",4]]")
  end
end
