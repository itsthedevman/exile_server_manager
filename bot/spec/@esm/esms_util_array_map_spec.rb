# frozen_string_literal: true

describe "ESMs_util_array_map", requires_connection: true, v2: true do
  include_context "connection"

  it "returns a new array" do
    response = execute_sqf!(
      <<~SQF
        private _result = [[1,2,3,4], { _this * 2 }] call ESMs_util_array_map;
        if (isNil "_result") exitWith { nil };

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([2, 4, 6, 8])
  end
end
