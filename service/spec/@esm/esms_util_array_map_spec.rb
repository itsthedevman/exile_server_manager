# frozen_string_literal: true

describe "ESMs_util_array_map", :requires_connection, v2: true do
  include_context "connection"

  it "returns a new array" do
    response = execute_sqf!(
      <<~SQF
        private _result = [[1,2,3,4], { _this * 2 }] call ESMs_util_array_map;
        if (isNil "_result") exitWith { nil };

        _result
      SQF
    )

    expect(response).to eq([2, 4, 6, 8])
  end

  context "when 'filter' is used (acts like #filter_map)" do
    it "returns a new array without `nil` values" do
      response = execute_sqf!(
        <<~SQF
          private _evaluator = {
            if ((_this % 2) isEqualTo 0) then {
              _this
            };
          };

          private _result = [[1,2,3,4], _evaluator, true] call ESMs_util_array_map;
          if (isNil "_result") exitWith { nil };

          _result
        SQF
      )

      expect(response).to eq([2, 4])
    end
  end
end
