# frozen_string_literal: true

describe "ESMs_system_territory_incrementPaymentCounter", :requires_connection, v2: true do
  include_context "connection"

  before { territory.create_flag }

  it "increments the counter" do
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        if (isNull _territory) exitWith { false };

        _territory call ESMs_system_territory_incrementPaymentCounter;
        _territory getVariable ["ESM_PaymentCounter", -1]
      SQF
    )

    expect(response).to eq(1)

    territory.reload
    expect(territory.esm_payment_counter).to eq(1)
  end

  it "increments the counter multiple times" do
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        if (isNull _territory) exitWith { false };

        _territory call ESMs_system_territory_incrementPaymentCounter;
        _territory call ESMs_system_territory_incrementPaymentCounter;
        _territory call ESMs_system_territory_incrementPaymentCounter;

        _territory getVariable ["ESM_PaymentCounter", -1]
      SQF
    )

    expect(response).to eq(3)

    territory.reload
    expect(territory.esm_payment_counter).to eq(3)
  end
end
