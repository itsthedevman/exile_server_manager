# frozen_string_literal: true

describe "ESMs_system_territory_get", :requires_connection, v2: true do
  include_context "connection"

  let!(:territory) do
    owner_uid = ESM::Test.steam_uid
    create(
      :exile_territory,
      owner_uid: owner_uid,
      moderators: [owner_uid, user.steam_uid],
      build_rights: [owner_uid, user.steam_uid],
      server_id: server.id
    )
  end

  before do
    user.exile_account
  end

  context "when the territory exists" do
    before do
      territory.create_flag
    end

    it "returns the flag object" do
      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          typeOf(_territory) isEqualTo "Exile_Construction_Flag_Static"
        SQF
      )

      expect(response).to be(true)
    end
  end

  context "when the territory does not exist" do
    before do
      territory.delete_flag
    end

    it "returns the flag object" do
      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          typeOf(_territory) isEqualTo "Exile_Construction_Flag_Static"
        SQF
      )

      expect(response).to be(false)
    end
  end
end
