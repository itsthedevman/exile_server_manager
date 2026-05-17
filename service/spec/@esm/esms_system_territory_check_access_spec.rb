# frozen_string_literal: true

describe "ESMs_system_territory_checkAccess", :requires_connection, v2: true do
  include_context "connection" do
    let!(:territory_moderators) { [user.steam_uid] }
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
          [_territory, #{user.steam_uid.in_quotes}, "moderator"] call ESMs_system_territory_checkAccess
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
          [_territory, #{user.steam_uid.in_quotes}, "moderator"] call ESMs_system_territory_checkAccess
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
          [_territory, #{user.steam_uid.in_quotes}, "moderator"] call ESMs_system_territory_checkAccess
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
          [_territory, #{user.steam_uid.in_quotes}, "owner"] call ESMs_system_territory_checkAccess
        SQF
      )

      expect(response).to be(false)
    end
  end
end
