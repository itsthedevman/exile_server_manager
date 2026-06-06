# frozen_string_literal: true

describe "ESMs_system_territory_incrementPaymentCounter", :requires_connection, v2: true do
  include_context "connection"

  before { territory.create_flag }

  it "increments the counter" do
    execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        if (isNull _territory) exitWith { false };

        _territory call ESMs_system_territory_incrementPaymentCounter;
      SQF
    )

    territory.reload
    expect(territory.esm_payment_counter).to eq(1)
  end

  it "increments the counter multiple times" do
    execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        if (isNull _territory) exitWith { false };

        _territory call ESMs_system_territory_incrementPaymentCounter;
        _territory call ESMs_system_territory_incrementPaymentCounter;
        _territory call ESMs_system_territory_incrementPaymentCounter;
      SQF
    )

    territory.reload
    expect(territory.esm_payment_counter).to eq(3)
  end
end
