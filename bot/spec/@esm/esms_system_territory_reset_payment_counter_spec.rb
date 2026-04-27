# frozen_string_literal: true

describe "ESMs_system_territory_resetPaymentCounter", :requires_connection, v2: true do
  include_context "connection" do
    let!(:territory_build_rights) { [user.steam_uid] }
  end

  context "when the player is a member of a territory" do
    before do
      territory.esm_payment_counter = 2
      territory.create_flag
    end

    it "resets the counter" do
      response = execute_sqf!(
        <<~SQF
          #{user.steam_uid.in_quotes} call ESMs_system_territory_resetPaymentCounter;

          private _territory = #{territory.id} call ESMs_system_territory_get;
          if (isNull _territory) exitWith { false };

          _territory getVariable ["ESM_PaymentCounter", -1]
        SQF
      )

      expect(response).to eq(0)

      territory.reload
      expect(territory.esm_payment_counter).to eq(0)
    end
  end

  context "when the player is not a member of any territories" do
    it "exits early" do
      response = execute_sqf!(
        <<~SQF
          #{user.steam_uid.in_quotes} call ESMs_system_territory_resetPaymentCounter;
          true
        SQF
      )

      expect(response).to eq(true)
    end
  end
end
