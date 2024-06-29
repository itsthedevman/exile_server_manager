# frozen_string_literal: true

describe "ESMs_system_territory_checkAccess", :requires_connection, v2: true do
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
    territory.create_flag
  end

  context "when the player is a moderator" do
    it "returns true" do
      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          [_territory, #{user.steam_uid.quoted}, "moderator"] call ESMs_system_territory_checkAccess
        SQF
      )

      expect(response).to be(true)
    end
  end

  context "when the player is a territory admin" do
    let!(:territory_admin_uids) { [user.steam_uid] }

    before do
      territory.revoke_membership(user.steam_uid)
    end

    it "returns true" do
      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          [_territory, #{user.steam_uid.quoted}, "moderator"] call ESMs_system_territory_checkAccess
        SQF
      )

      expect(response).to be(true)
    end
  end

  context "when the player is not a member of the territory" do
    before do
      territory.revoke_membership(user.steam_uid)
    end

    it "returns false" do
      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          [_territory, #{user.steam_uid.quoted}, "moderator"] call ESMs_system_territory_checkAccess
        SQF
      )

      expect(response).to be(false)
    end
  end

  context "when the player does not have high enough permissions" do
    it "returns false" do
      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          [_territory, #{user.steam_uid.quoted}, "owner"] call ESMs_system_territory_checkAccess
        SQF
      )

      expect(response).to be(false)
    end
  end
end
