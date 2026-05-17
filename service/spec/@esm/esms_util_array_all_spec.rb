# frozen_string_literal: true

describe "ESMs_util_array_all", :requires_connection, v2: true do
  include_context "connection"

  context "when every item in the array passes validation" do
    it "returns true" do
      response = execute_sqf!(
        <<~SQF
          private _result = [[1,2,3,4], { _this != 0 }] call ESMs_util_array_all;
          if (isNil "_result") exitWith { nil };

          _result
        SQF
      )

      expect(response).to be(true)
    end
  end

  context "when every item in the array do not pass validation" do
    it "returns false" do
      response = execute_sqf!(
        <<~SQF
          private _result = [[1,2,3,4], { _this isEqualType "" }] call ESMs_util_array_all;
          if (isNil "_result") exitWith { nil };

          _result
        SQF
      )

      expect(response).to be(false)
    end
  end

  context "when some items in the array do not pass validation" do
    it "returns false" do
      response = execute_sqf!(
        <<~SQF
          private _result = [[1,2,3,4], { _this > 1 }] call ESMs_util_array_all;
          if (isNil "_result") exitWith { nil };

          _result
        SQF
      )

      expect(response).to be(false)
    end
  end
end
