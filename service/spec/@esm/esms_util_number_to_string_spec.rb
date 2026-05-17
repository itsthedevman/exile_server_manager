# frozen_string_literal: true

describe "ESMs_util_number_toString", requires_connection: true do
  include_context "connection"

  subject(:formatted_string) { execute_sqf!("#{number} call ESMs_util_number_toString") }

  context "when the number is positive" do
    let(:number) { 12_345 }

    it "is converted to a comma separated string" do
      is_expected.to eq("12,345")
    end
  end

  context "when the number is negative" do
    let(:number) { -654_321 }

    it "is converted to a comma separated string with a negative sign" do
      is_expected.to eq("-654,321")
    end
  end

  context "when the number is in scientific notation" do
    let(:number) { "1234e007" }

    it "is converted into a full comma separated number" do
      is_expected.to eq("12,340,000,000")
    end
  end
end
