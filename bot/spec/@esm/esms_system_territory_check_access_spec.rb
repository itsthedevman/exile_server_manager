# frozen_string_literal: true

describe "ESMs_system_territory_checkAccess", requires_connection: true, v2: true do
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

  it "returns true because the Player has correct permissions" do
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "moderator"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(true)
  end

  it "returns true because the Player is a Territory Admin", :territory_admin_bypass do
    territory.revoke_membership(user.steam_uid)

    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "moderator"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(true)
  end

  it "returns false because the Player is missing rights" do
    territory.revoke_membership(user.steam_uid)

    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "moderator"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(false)
  end

  it "returns false because the Player has lower than required permissions" do
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "owner"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(false)
  end
end
